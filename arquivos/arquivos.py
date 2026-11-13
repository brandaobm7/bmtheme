"""Arquivos do bmos: a parte que lê pastas e move arquivos para a janela Arquivos.qml.

É carregada pelo bmos-arquivos.py, que abre a janela. A classe não guarda em que
pasta a janela está: a janela pergunta e manda fazer.

Veio do bmos em Debian. No tema para o Plasma
mudaram o terminal, que é o do sistema, e a área de transferência, que também
fala o formato do Dolphin.

Regras para nunca perder arquivos:
- Copiar ou mover para onde já existe algo com o mesmo nome nunca substitui:
  o novo recebe outro nome ("foto 2.png"), como o "Manter ambos" do Mac.
- Apagar sempre manda para a Lixeira (gio trash). Só "Esvaziar Lixeira" apaga
  de vez.
"""

import json
import mimetypes
import os
import re
import shutil
import subprocess
import sys
import threading
import time
import unicodedata
import urllib.parse

from PySide6.QtCore import Property, QFileSystemWatcher, QMimeData, QObject, QTimer, QUrl, Signal, Slot
from PySide6.QtGui import QGuiApplication, QIcon

AQUI = os.path.dirname(os.path.realpath(__file__))

DEMO = os.environ.get("BMOS_ARQUIVOS_DEMO") == "1"
CASA = os.path.expanduser("~")
LIXEIRA = os.path.join(os.environ.get("XDG_DATA_HOME") or os.path.join(CASA, ".local/share"), "Trash")
MARCADORES = os.path.join(CASA, ".config/gtk-3.0/bookmarks")
RECENTES = os.path.join(os.environ.get("XDG_DATA_HOME") or os.path.join(CASA, ".local/share"), "recently-used.xbel")
COPIADOS = "x-special/gnome-copied-files"  # formato que o Nemo e o Nautilus também entendem
# Cores de pasta: nome no menu e ícone do tema. Só entram as que o tema de ícones tiver.
CORES_DE_PASTA = [("Vermelha", "folder-red"), ("Laranja", "folder-orange"), ("Amarela", "folder-yellow"),
                  ("Verde", "folder-green"), ("Ciano", "folder-cyan"), ("Azul", "folder-blue"),
                  ("Roxa", "folder-violet"), ("Rosa", "folder-magenta"), ("Marrom", "folder-brown"),
                  ("Cinza", "folder-grey"), ("Preta", "folder-black")]
# Arquivo em que o Dolphin e os outros gerenciadores guardam o ícone escolhido para uma pasta.
MARCA_DA_PASTA = ".directory"


def icone_escolhido(pasta):
    """Ícone gravado no arquivo .directory da pasta, ou vazio."""
    try:
        with open(os.path.join(pasta, MARCA_DA_PASTA), encoding="utf-8", errors="replace") as arquivo:
            for linha in arquivo:
                if linha.startswith("Icon="):
                    return linha[5:].strip()
    except OSError:
        pass
    return ""


# Arrumação da barra lateral feita pela pessoa: a ordem de cada grupo, os nomes
# trocados e os favoritos retirados. Cada item é reconhecido por uma chave: o
# caminho da pasta, ou o dispositivo, no caso de um disco ainda não montado.
ARRUMACAO = os.path.join(CASA, ".config/bmos/arquivos.json")


def ler_arrumacao():
    try:
        with open(ARRUMACAO, encoding="utf-8") as arquivo:
            dados = json.load(arquivo)
    except (OSError, ValueError):
        dados = {}
    if not isinstance(dados, dict):
        dados = {}
    ordem = dados.get("ordem") if isinstance(dados.get("ordem"), dict) else {}
    return {
        "ordem": {grupo: [str(c) for c in ordem.get(grupo, [])] for grupo in ("favoritos", "locais")},
        "nomes": {str(c): str(n) for c, n in (dados.get("nomes") or {}).items()} if isinstance(dados.get("nomes"), dict) else {},
        "retirados": [str(c) for c in dados.get("retirados", [])] if isinstance(dados.get("retirados"), list) else [],
    }


def gravar_arrumacao(dados):
    os.makedirs(os.path.dirname(ARRUMACAO), exist_ok=True)
    with open(ARRUMACAO, "w", encoding="utf-8") as arquivo:
        json.dump(dados, arquivo, ensure_ascii=False, indent=2)


def arrumar(itens, ordem, nomes):
    """Aplica a ordem e os nomes escolhidos pela pessoa a uma lista de itens da barra lateral.
    Um item que a ordem guardada não conhece (um pendrive novo) fica onde estaria sem ela:
    logo depois do item que vem antes dele na lista de origem."""
    posicao = {chave: i for i, chave in enumerate(ordem)}
    ultimo, pesos = -1.0, []
    for indice, item in enumerate(itens):
        if item["chave"] in posicao:
            ultimo = float(posicao[item["chave"]])
            pesos.append((ultimo, 0, indice))
        else:
            pesos.append((ultimo, 1, indice))
    arrumados = [itens[indice] for _, _, indice in sorted(pesos)]
    return [dict(item, nome=nomes.get(item["chave"], item["nome"])) for item in arrumados]


# Onde as partições do próprio sistema ficam montadas. Elas não entram na barra lateral.
PONTOS_DO_SISTEMA = {"/", "/boot", "/boot/efi", "/efi", "/usr", "/etc", "/var", "/var/home", "/home", "[SWAP]"}
RECORTE_KDE = "application/x-kde-cutselection"  # o Dolphin marca assim o que foi recortado
# Terminais conhecidos, com a opção de cada um para abrir numa pasta.
TERMINAIS = [("ptyxis", ["--new-window", "-d"]), ("konsole", ["--workdir"]),
             ("gnome-terminal", ["--working-directory"]), ("kgx", ["--working-directory"])]
IMAGENS = {"png", "jpg", "jpeg", "webp", "gif", "bmp", "svg"}

# Pastas especiais: nome na barra lateral, ícone Tabler e ícone do tema para a grade.
ESPECIAIS = [
    ("DESKTOP", "Área de trabalho", "device-desktop", "user-desktop"),
    ("DOCUMENTS", "Documentos", "file-text", "folder-documents"),
    ("DOWNLOAD", "Downloads", "download", "folder-download"),
    ("PICTURES", "Imagens", "photo", "folder-pictures"),
    ("MUSIC", "Músicas", "music", "folder-music"),
    ("VIDEOS", "Vídeos", "movie", "folder-videos"),
]

TIPOS = {
    "png": "Imagem PNG", "jpg": "Imagem JPEG", "jpeg": "Imagem JPEG", "webp": "Imagem WebP", "gif": "Imagem GIF",
    "bmp": "Imagem BMP", "svg": "Imagem SVG", "pdf": "Documento PDF", "txt": "Texto", "md": "Texto",
    "doc": "Documento do Word", "docx": "Documento do Word", "odt": "Documento de texto",
    "xls": "Planilha do Excel", "xlsx": "Planilha do Excel", "ods": "Planilha", "csv": "Planilha CSV",
    "ppt": "Apresentação", "pptx": "Apresentação", "odp": "Apresentação",
    "mp3": "Áudio MP3", "flac": "Áudio FLAC", "wav": "Áudio WAV", "ogg": "Áudio Ogg", "m4a": "Áudio AAC",
    "mp4": "Vídeo MP4", "mkv": "Vídeo MKV", "avi": "Vídeo AVI", "mov": "Vídeo MOV", "webm": "Vídeo WebM",
    "zip": "Arquivo ZIP", "rar": "Arquivo RAR", "7z": "Arquivo 7z", "gz": "Arquivo compactado",
    "xz": "Arquivo compactado", "tar": "Arquivo TAR", "iso": "Imagem de disco", "deb": "Pacote Debian",
    "exe": "Programa do Windows", "msi": "Instalador do Windows", "sh": "Script", "py": "Script Python",
    "html": "Página da web", "json": "Dados JSON", "desktop": "Atalho de app", "appimage": "App AppImage",
}


def rodar(comando, tempo=15):
    try:
        r = subprocess.run(comando, capture_output=True, text=True, timeout=tempo)
        return r.returncode, (r.stdout or "") + (r.stderr or "")
    except (OSError, subprocess.SubprocessError) as erro:
        return 127, str(erro)


def soltar(comando):
    try:
        subprocess.Popen(comando, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    except OSError:
        pass


def tamanho_legivel(numero):
    """1536 -> '1,5 KB', no jeito brasileiro (vírgula) e com múltiplos de 1000, como no Mac."""
    if numero < 1000:
        return f"{numero} bytes"
    for unidade in ("KB", "MB", "GB", "TB"):
        numero /= 1000
        if numero < 1000 or unidade == "TB":
            texto = f"{numero:.1f}" if numero < 100 else f"{numero:.0f}"
            return texto.replace(".", ",") + " " + unidade
    return ""


def data_legivel(instante):
    """Hoje 14:32, Ontem 09:10 ou 03/11/2026 18:45."""
    if not instante:
        return ""
    quando, agora = time.localtime(instante), time.localtime()
    hora = time.strftime("%H:%M", quando)
    if quando[:3] == agora[:3]:
        return "Hoje " + hora
    ontem = time.localtime(time.time() - 86400)
    if quando[:3] == ontem[:3]:
        return "Ontem " + hora
    return time.strftime("%d/%m/%Y ", quando) + hora


def chave_natural(nome):
    """Ordem como a do Finder: sem diferenciar maiúsculas nem acentos, e com 'foto 2' antes de 'foto 10'."""
    texto = "".join(c for c in unicodedata.normalize("NFKD", nome.casefold()) if not unicodedata.combining(c))
    return [(0, int(parte), "") if parte.isdigit() else (1, 0, parte) for parte in re.split(r"(\d+)", texto) if parte]


def pastas_do_usuario():
    """Pastas especiais (Documentos, Downloads...) do ~/.config/user-dirs.dirs."""
    pastas = {}
    try:
        with open(os.path.join(CASA, ".config/user-dirs.dirs"), encoding="utf-8") as arquivo:
            for linha in arquivo:
                achado = re.match(r'XDG_(\w+)_DIR="(.*)"', linha.strip())
                if achado:
                    pastas[achado.group(1)] = os.path.normpath(achado.group(2).replace("$HOME", CASA))
    except OSError:
        pass
    padrao = {"DESKTOP": "Área de trabalho", "DOCUMENTS": "Documentos", "DOWNLOAD": "Downloads",
              "PICTURES": "Imagens", "MUSIC": "Músicas", "VIDEOS": "Vídeos"}
    for chave, nome in padrao.items():
        pastas.setdefault(chave, os.path.join(CASA, nome))
    return pastas


def para_caminho(texto):
    """Aceita caminho ou endereço file:// e devolve o caminho. O endereço da
    lixeira do sistema (trash:/) vira o nome que o app dá a ela."""
    if texto.startswith("trash:"):
        return "lixeira:"
    if texto.startswith("file://"):
        return urllib.parse.unquote(urllib.parse.urlparse(texto).path)
    return texto


class Arquivos(QObject):
    pastaMudou = Signal(str)        # o conteúdo de uma pasta observada mudou
    locaisMudaram = Signal()        # pendrive ou disco entrou, saiu ou foi montado
    favoritosMudaram = Signal()
    tarefaMudou = Signal()          # cópia ou movimentação em andamento
    areaMudou = Signal()            # há (ou não há mais) arquivos copiados para colar
    aviso = Signal(str)             # mensagem curta para a janela mostrar

    def __init__(self):
        super().__init__()
        self._especiais = pastas_do_usuario()
        self._icones_de_pasta = {CASA: "user-home"}
        for chave, _, _, icone in ESPECIAIS:
            self._icones_de_pasta[self._especiais[chave]] = icone
        self._tarefa = {"ativa": False, "texto": "", "fracao": 0.0}
        self._pode_colar = False
        self._locais = []
        self._observadas = {}
        self._vigia = QFileSystemWatcher(self)
        self._vigia.directoryChanged.connect(self._mudou)
        self._pendentes = set()
        self._espera = QTimer(self)
        self._espera.setSingleShot(True)
        self._espera.setInterval(250)
        self._espera.timeout.connect(self._avisar_mudancas)
        self._vigiar_locais()
        area = QGuiApplication.clipboard()
        if area is not None:
            area.dataChanged.connect(self._ver_area)
            self._ver_area()
        threading.Thread(target=self._ler_locais, daemon=True).start()

    tarefa = Property("QVariantMap", lambda self: self._tarefa, notify=tarefaMudou)
    podeColar = Property(bool, lambda self: self._pode_colar, notify=areaMudou)
    casa = Property(str, lambda self: CASA, constant=True)

    # ------------------------------------------------------------ listar

    def _item(self, caminho, nome=None, estado=None):
        nome = nome if nome is not None else os.path.basename(caminho)
        try:
            estado = estado or os.stat(caminho)
        except OSError:
            try:
                estado = os.lstat(caminho)  # atalho quebrado
            except OSError:
                return None
        pasta = os.path.isdir(caminho)
        extensao = "" if pasta else os.path.splitext(nome)[1].lstrip(".").lower()
        if pasta:
            # Uma cor escolhida para a pasta vale mais que o ícone padrão dela.
            icone = icone_escolhido(caminho) or self._icones_de_pasta.get(caminho, "folder")
            tipo = "Pasta"
        else:
            tipo = TIPOS.get(extensao) or (f"Arquivo {extensao.upper()}" if extensao else "Documento")
            mime = mimetypes.guess_type(nome)[0] or ""
            candidatos = [mime.replace("/", "-")] if mime else []
            if mime:
                candidatos.append(mime.split("/")[0] + "-x-generic")
            if extensao in ("zip", "rar", "7z", "gz", "xz", "tar", "deb", "iso"):
                candidatos.append("package-x-generic")
            candidatos.append("text-x-generic")
            icone = "|".join(candidatos)
        return {
            "nome": nome, "caminho": caminho, "pasta": pasta, "oculto": nome.startswith("."),
            "tamanho": -1 if pasta else estado.st_size,
            "tamanhoTexto": "—" if pasta else tamanho_legivel(estado.st_size),
            "modificado": estado.st_mtime, "modificadoTexto": data_legivel(estado.st_mtime),
            "tipo": tipo, "icone": icone,
            # Imagens mostram a própria miniatura; o endereço já vai pronto para o QML.
            "miniatura": QUrl.fromLocalFile(caminho).toString()
            if extensao in IMAGENS and estado.st_size < 40_000_000 else "",
        }

    @Slot(str, bool, result="QVariantList")
    def listar(self, caminho, ocultos):
        if caminho == "recentes:":
            return self._listar_recentes()
        if caminho == "lixeira:":
            caminho = os.path.join(LIXEIRA, "files")
        itens = []
        try:
            with os.scandir(caminho) as entradas:
                for entrada in entradas:
                    if not ocultos and entrada.name.startswith("."):
                        continue
                    item = self._item(entrada.path, entrada.name)
                    if item:
                        itens.append(item)
        except OSError:
            return []
        itens.sort(key=lambda i: (not i["pasta"], chave_natural(i["nome"])))
        return itens

    def _listar_recentes(self):
        """Arquivos abertos há pouco, do registro que os apps GTK mantêm."""
        try:
            with open(RECENTES, encoding="utf-8", errors="replace") as arquivo:
                texto = arquivo.read()
        except OSError:
            return []
        vistos, itens = set(), []
        for endereco in re.findall(r'<bookmark href="(file://[^"]+)"', texto):
            caminho = para_caminho(endereco.replace("&amp;", "&"))
            if caminho in vistos or not os.path.isfile(caminho):
                continue
            vistos.add(caminho)
            item = self._item(caminho)
            if item:
                itens.append(item)
        itens.sort(key=lambda i: -i["modificado"])
        return itens[:60]

    @Slot(str, result="QVariantMap")
    def info(self, caminho):
        """Nome, pasta de cima e espaço livre de uma pasta, para o título e o rodapé."""
        if caminho == "recentes:":
            return {"nome": "Recentes", "pai": "", "livre": "", "existe": True, "gravavel": False, "partes": []}
        if caminho == "lixeira:":
            return {"nome": "Lixeira", "pai": "", "livre": "", "existe": True, "gravavel": False, "partes": []}
        existe = os.path.isdir(caminho)
        livre = ""
        if existe:
            try:
                livre = tamanho_legivel(shutil.disk_usage(caminho).free) + " livres"
            except OSError:
                pass
        # Caminho do rodapé: da pasta pessoal (ou da raiz) até aqui, um pedaço por pasta.
        partes, atual = [], caminho
        while True:
            if atual == CASA:
                partes.append({"nome": "Pasta pessoal", "caminho": atual})
                break
            if atual == "/":
                partes.append({"nome": "Computador", "caminho": "/"})
                break
            partes.append({"nome": os.path.basename(atual), "caminho": atual})
            atual = os.path.dirname(atual)
        partes.reverse()
        if caminho == CASA:
            nome = "Pasta pessoal"
        elif caminho == "/":
            nome = "Computador"
        else:
            nome = os.path.basename(caminho)
        return {"nome": nome, "pai": "" if caminho == "/" else os.path.dirname(caminho), "livre": livre,
                "existe": existe, "gravavel": existe and os.access(caminho, os.W_OK), "partes": partes}

    @Slot(str, result=str)
    def resolver(self, texto):
        """Caminho pedido por fora (bmos-controle arquivos CAMINHO): pasta, ou a pasta do arquivo."""
        if texto and para_caminho(texto) == "lixeira:":
            return "lixeira:"
        caminho = os.path.normpath(os.path.expanduser(para_caminho(texto))) if texto else CASA
        if os.path.isdir(caminho):
            return caminho
        if os.path.exists(caminho):
            return os.path.dirname(caminho)
        return CASA

    # ------------------------------------------------------------ barra lateral

    @Slot(result="QVariantList")
    def favoritos(self):
        """Favoritos da barra lateral, já na ordem e com os nomes que a pessoa escolheu."""
        arrumacao = ler_arrumacao()
        lista = [f for f in self._favoritos_de_origem() if f["chave"] not in arrumacao["retirados"]]
        return arrumar(lista, arrumacao["ordem"]["favoritos"], arrumacao["nomes"])

    def _favoritos_de_origem(self):
        lista = [{"nome": "Recentes", "caminho": "recentes:", "icone": "clock", "fixo": True},
                 {"nome": "Pasta pessoal", "caminho": CASA, "icone": "home", "fixo": True}]
        vistos = {CASA}
        for chave, nome, icone, _ in ESPECIAIS:
            caminho = self._especiais[chave]
            if os.path.isdir(caminho) and caminho not in vistos:
                vistos.add(caminho)
                lista.append({"nome": nome, "caminho": caminho, "icone": icone, "fixo": True})
        # Favoritos que você adicionou. É a mesma lista do Nemo e das janelas de abrir e salvar.
        try:
            with open(MARCADORES, encoding="utf-8") as arquivo:
                for linha in arquivo:
                    endereco, _, nome = linha.strip().partition(" ")
                    caminho = para_caminho(endereco)
                    if endereco.startswith("file://") and os.path.isdir(caminho) and caminho not in vistos:
                        vistos.add(caminho)
                        lista.append({"nome": nome or os.path.basename(caminho), "caminho": caminho,
                                      "icone": "folder", "fixo": False})
        except OSError:
            pass
        for item in lista:
            item["chave"] = item["caminho"]
        return lista

    @Slot(str)
    def adicionarFavorito(self, caminho):
        if not os.path.isdir(caminho):
            return
        arrumacao = ler_arrumacao()
        if caminho in arrumacao["retirados"]:
            # Era um favorito padrão que tinha sido retirado: volta para a lista.
            arrumacao["retirados"].remove(caminho)
            gravar_arrumacao(arrumacao)
        elif not any(f["caminho"] == caminho for f in self._favoritos_de_origem()):
            os.makedirs(os.path.dirname(MARCADORES), exist_ok=True)
            with open(MARCADORES, "a", encoding="utf-8") as arquivo:
                arquivo.write(QUrl.fromLocalFile(caminho).toString() + "\n")
        self.favoritosMudaram.emit()

    @Slot(str)
    def removerFavorito(self, caminho):
        """Tira um favorito da barra lateral. Os que você adicionou saem da lista de marcadores.
        Os padrão (Recentes, Documentos...) ficam só guardados como retirados, e voltam com
        "Adicionar aos Favoritos" ou "Restaurar a barra lateral"."""
        origem = next((f for f in self._favoritos_de_origem() if f["caminho"] == caminho), None)
        if origem is None:
            return
        arrumacao = ler_arrumacao()
        if origem["fixo"]:
            if caminho not in arrumacao["retirados"]:
                arrumacao["retirados"].append(caminho)
        else:
            try:
                with open(MARCADORES, encoding="utf-8") as arquivo:
                    linhas = arquivo.readlines()
                restantes = [l for l in linhas if para_caminho(l.strip().partition(" ")[0]) != caminho]
                with open(MARCADORES, "w", encoding="utf-8") as arquivo:
                    arquivo.writelines(restantes)
            except OSError:
                return
        # O nome trocado e o lugar na ordem não valem mais para um item que saiu.
        arrumacao["nomes"].pop(caminho, None)
        arrumacao["ordem"]["favoritos"] = [c for c in arrumacao["ordem"]["favoritos"] if c != caminho]
        gravar_arrumacao(arrumacao)
        self.favoritosMudaram.emit()

    @Slot(str, str, int)
    def moverNaLateral(self, grupo, chave, posicao):
        """Põe um item da barra lateral em outra posição dentro do grupo dele ("favoritos" ou "locais")."""
        if grupo not in ("favoritos", "locais"):
            return
        chaves = [i["chave"] for i in (self.favoritos() if grupo == "favoritos" else self.locais())]
        if chave not in chaves:
            return
        chaves.remove(chave)
        chaves.insert(max(0, min(len(chaves), posicao)), chave)
        arrumacao = ler_arrumacao()
        arrumacao["ordem"][grupo] = chaves
        gravar_arrumacao(arrumacao)
        (self.favoritosMudaram if grupo == "favoritos" else self.locaisMudaram).emit()

    @Slot(str, str)
    def renomearNaLateral(self, chave, nome):
        """Troca o nome que aparece na barra lateral. A pasta em si não muda de nome.
        Nome vazio devolve o nome original."""
        arrumacao = ler_arrumacao()
        nome = nome.strip()
        if nome:
            arrumacao["nomes"][chave] = nome
        else:
            arrumacao["nomes"].pop(chave, None)
        gravar_arrumacao(arrumacao)
        self.favoritosMudaram.emit()
        self.locaisMudaram.emit()

    @Slot()
    def restaurarLateral(self):
        """Desfaz a arrumação: ordem original, nomes originais e os favoritos padrão de volta."""
        gravar_arrumacao({"ordem": {"favoritos": [], "locais": []}, "nomes": {}, "retirados": []})
        self.favoritosMudaram.emit()
        self.locaisMudaram.emit()

    @Slot(result="QVariantList")
    def locais(self):
        """Locais da barra lateral, já na ordem e com os nomes que a pessoa escolheu."""
        arrumacao = ler_arrumacao()
        # A chave de um disco é o dispositivo, que não muda quando ele é montado ou desmontado.
        lista = [dict(local, chave=local["dispositivo"] or local["caminho"]) for local in self._locais]
        return arrumar(lista, arrumacao["ordem"]["locais"], arrumacao["nomes"])

    def _ler_locais(self):
        """Computador, pendrives e outros discos (lsblk), menos as partições do próprio sistema."""
        lista = [{"nome": "Computador", "caminho": "/", "dispositivo": "", "icone": "device-laptop",
                  "removivel": False, "montado": True}]
        if DEMO:
            lista.append({"nome": "PENDRIVE", "caminho": "/media/demo/PENDRIVE", "dispositivo": "/dev/sdb1",
                          "icone": "usb", "removivel": True, "montado": True})
        else:
            codigo, saida = rodar(["lsblk", "-J", "-o", "PATH,LABEL,SIZE,FSTYPE,MOUNTPOINTS,RM,HOTPLUG,TYPE,PARTTYPENAME"], 6)
            try:
                dispositivos = json.loads(saida).get("blockdevices", []) if codigo == 0 else []
            except ValueError:
                dispositivos = []

            def percorrer(nos, removivel_pai=False):
                for no in nos:
                    removivel = removivel_pai or bool(no.get("rm")) or bool(no.get("hotplug"))
                    # Uma partição pode estar montada em vários lugares. No Fedora atômico, a do
                    # sistema aparece em /var, /etc, /sysroot e na pasta pessoal, e não em "/".
                    pontos = [p for p in (no.get("mountpoints") or []) if p]
                    ponto, sistema_de_arquivos = (pontos[0] if pontos else ""), no.get("fstype") or ""
                    do_sistema = any(p in PONTOS_DO_SISTEMA or p.startswith(("/run/live", "/sysroot")) for p in pontos)
                    tecnico = sistema_de_arquivos in ("", "swap", "LVM2_member", "crypto_LUKS", "squashfs") or \
                        "EFI" in (no.get("parttypename") or "")
                    if no.get("type") in ("part", "disk", "rom") and not do_sistema and not tecnico:
                        tamanho = re.sub(r"([KMGT])$", r" \1B", (no.get("size") or "").strip())
                        lista.append({
                            "nome": no.get("label") or f"Disco de {tamanho}",
                            "caminho": ponto, "dispositivo": no.get("path") or "",
                            "icone": "usb" if removivel else "device-laptop",
                            "removivel": removivel, "montado": bool(ponto)})
                    percorrer(no.get("children") or [], removivel)

            percorrer(dispositivos)
        lista.append({"nome": "Lixeira", "caminho": "lixeira:", "dispositivo": "", "icone": "trash",
                      "removivel": False, "montado": True})
        if lista != self._locais:
            self._locais = lista
            self.locaisMudaram.emit()

    def _vigiar_locais(self):
        usuario = os.environ.get("USER", "")
        # O Fedora monta pendrives em /run/media/<usuário>; o Debian, em /media/<usuário>.
        for pasta in ("/dev/disk/by-uuid", "/media", os.path.join("/media", usuario),
                      "/run/media", os.path.join("/run/media", usuario)):
            if os.path.isdir(pasta) and pasta not in self._vigia.directories():
                self._vigia.addPath(pasta)

    @Slot(str, result=str)
    def montar(self, dispositivo):
        """Monta um disco ou pendrive e devolve a pasta. Vazio se não deu."""
        codigo, saida = rodar(["udisksctl", "mount", "-b", dispositivo, "--no-user-interaction"], 20)
        achado = re.search(r" at (/.+?)\.?\s*$", saida.strip())
        if codigo == 0 and achado:
            self._ler_locais()
            return achado.group(1)
        for local in self._locais:  # já estava montado
            if local["dispositivo"] == dispositivo and local["caminho"]:
                return local["caminho"]
        self.aviso.emit("Não foi possível abrir este disco.")
        return ""

    @Slot(str)
    def ejetar(self, dispositivo):
        def ejetar():
            codigo, saida = rodar(["udisksctl", "unmount", "-b", dispositivo, "--no-user-interaction"], 30)
            if codigo != 0 and "not mounted" not in saida.lower():
                self.aviso.emit("O disco está em uso. Feche o que estiver aberto nele e tente de novo.")
                return
            disco = re.sub(r"p?\d+$", "", dispositivo)
            rodar(["udisksctl", "power-off", "-b", disco, "--no-user-interaction"], 15)
            self.aviso.emit("Pode remover o disco.")
            self._ler_locais()

        threading.Thread(target=ejetar, daemon=True).start()

    # ------------------------------------------------------------ observar pastas

    @Slot(str, str)
    def observar(self, antiga, nova):
        """A janela saiu de uma pasta e entrou em outra: atualiza quem é observado."""
        for caminho, soma in ((antiga, -1), (nova, 1)):
            caminho = os.path.join(LIXEIRA, "files") if caminho == "lixeira:" else caminho
            if not caminho or not caminho.startswith("/"):
                continue
            total = self._observadas.get(caminho, 0) + soma
            if total <= 0:
                self._observadas.pop(caminho, None)
                self._vigia.removePath(caminho)
            else:
                self._observadas[caminho] = total
                if os.path.isdir(caminho):
                    self._vigia.addPath(caminho)

    def _mudou(self, caminho):
        self._pendentes.add(caminho)
        self._espera.start()

    def _avisar_mudancas(self):
        pendentes, self._pendentes = self._pendentes, set()
        for caminho in pendentes:
            if caminho.startswith(("/dev/", "/media", "/run/media")):
                self._vigiar_locais()
                threading.Thread(target=self._ler_locais, daemon=True).start()
            if caminho == os.path.join(LIXEIRA, "files"):
                self.pastaMudou.emit("lixeira:")
            self.pastaMudou.emit(caminho)

    # ------------------------------------------------------------ abrir

    @Slot(str)
    def abrir(self, caminho):
        soltar(["xdg-open", caminho])

    # ----- abrir com outro app

    @Slot(str, result="QVariantList")
    def appsPara(self, caminho):
        """Apps registrados para o tipo deste arquivo ou pasta: [{id, nome, arquivo, icone}], o padrão primeiro."""
        if os.path.isdir(caminho):
            tipo = "inode/directory"  # para pastas, o xdg-mime nem sempre responde
        else:
            _, tipo = rodar(["xdg-mime", "query", "filetype", caminho], 5)
            tipo = tipo.strip() or (mimetypes.guess_type(caminho)[0] or "")
        if not tipo:
            return []
        _, saida = rodar(["gio", "mime", tipo], 5)
        ids = []
        for linha in saida.splitlines():
            linha = linha.strip()
            if ":" in linha and ".desktop" in linha:      # "Aplicativo padrão para ...: nome.desktop"
                linha = linha.rsplit(":", 1)[1].strip()
            if linha.endswith(".desktop") and linha not in ids:
                ids.append(linha)
        # As mesmas pastas em que o sistema procura apps, com as do Flatpak.
        dados = [os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share")]
        dados += (os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share").split(":")
        pastas = [os.path.join(d, "applications") for d in dados if d]
        apps = []
        for ident in ids:
            arquivo = next((os.path.join(p, ident) for p in pastas if os.path.exists(os.path.join(p, ident))), "")
            if not arquivo:
                continue
            campos = {}
            try:
                with open(arquivo, encoding="utf-8", errors="replace") as leitura:
                    secao = ""
                    for linha in leitura:
                        linha = linha.strip()
                        if linha.startswith("["):
                            secao = linha
                        elif secao == "[Desktop Entry]" and "=" in linha:
                            chave, valor = linha.split("=", 1)
                            campos.setdefault(chave, valor)
            except OSError:
                continue
            # O Arquivos do bmos não entra: ele abre pastas, e aqui o que se escolhe é um app para o arquivo.
            if campos.get("NoDisplay") == "true" or ident == "org.bmos.arquivos.desktop":
                continue
            nome = campos.get("Name[pt_BR]") or campos.get("Name[pt]") or campos.get("Name") or ident
            apps.append({"id": ident, "nome": nome, "arquivo": arquivo, "icone": campos.get("Icon", "")})
        return apps[:12]

    @Slot(str, str)
    def abrirCom(self, arquivo_do_app, caminho):
        soltar(["gio", "launch", arquivo_do_app, caminho])

    # ----- pré-visualização (Espaço)

    @Slot(str, result="QVariantMap")
    def previa(self, caminho):
        """O que mostrar na pré-visualização: imagem inteira, começo do texto ou só os dados do arquivo."""
        item = self._item(caminho)
        if item is None:
            return {}
        r = {"nome": item["nome"], "tipo": item["tipo"], "tamanho": item["tamanhoTexto"],
             "modificado": item["modificadoTexto"], "icone": item["icone"], "pasta": item["pasta"],
             "caminho": caminho, "classe": "outro", "texto": "", "imagem": ""}
        if item["pasta"]:
            try:
                r["tamanho"] = f"{len(os.listdir(caminho))} itens"
            except OSError:
                pass
            return r
        if item["miniatura"]:
            r.update(classe="imagem", imagem=item["miniatura"])
            return r
        try:
            with open(caminho, "rb") as leitura:
                bruto = leitura.read(24000)
        except OSError:
            return r
        if bruto and b"\x00" not in bruto:
            # O corte em 24 mil bytes pode partir uma letra acentuada no fim: até duas
            # letras ilegíveis ainda contam como texto. Mais que isso é arquivo binário.
            texto = bruto.decode("utf-8", errors="replace")
            if texto.count("�") <= 2:
                r.update(classe="texto", texto="\n".join(texto.splitlines()[:200]))
        return r

    @Slot(str)
    def abrirTerminal(self, pasta):
        for comando, opcao in TERMINAIS:
            if shutil.which(comando):
                soltar([comando] + opcao + [pasta])
                return
        self.aviso.emit("Nenhum terminal conhecido foi encontrado.")

    # ------------------------------------------------------------ criar e renomear

    @staticmethod
    def _nome_livre(pasta, nome, copia=False):
        """'foto.png' -> 'foto 2.png' (ou 'foto cópia.png'), até achar um nome que não existe."""
        base, extensao = os.path.splitext(nome)
        if os.path.isdir(os.path.join(pasta, nome)) or nome.startswith("."):
            base, extensao = nome, ""
        if copia:
            candidato = f"{base} cópia{extensao}"
            if not os.path.lexists(os.path.join(pasta, candidato)):
                return os.path.join(pasta, candidato)
            base = f"{base} cópia"
        numero = 2
        while os.path.lexists(os.path.join(pasta, f"{base} {numero}{extensao}")):
            numero += 1
        return os.path.join(pasta, f"{base} {numero}{extensao}")

    @Slot(str, result=str)
    def novaPasta(self, pasta):
        """Cria 'Nova pasta' (ou 'Nova pasta 2'...) e devolve o caminho, para a janela já renomear."""
        caminho = os.path.join(pasta, "Nova pasta")
        if os.path.lexists(caminho):
            caminho = self._nome_livre(pasta, "Nova pasta")
        try:
            os.mkdir(caminho)
        except OSError:
            self.aviso.emit("Não foi possível criar a pasta aqui.")
            return ""
        return caminho

    @Slot(str, str, result=str)
    def renomear(self, caminho, novo):
        """Devolve o novo caminho, ou vazio se não renomeou (com aviso)."""
        novo = novo.strip()
        if not novo or novo == os.path.basename(caminho):
            return ""
        if "/" in novo or novo in (".", ".."):
            self.aviso.emit("O nome não pode ter barra (/).")
            return ""
        destino = os.path.join(os.path.dirname(caminho), novo)
        if os.path.lexists(destino):
            self.aviso.emit(f"Já existe \"{novo}\" nesta pasta.")
            return ""
        try:
            os.rename(caminho, destino)
        except OSError:
            self.aviso.emit("Não foi possível renomear.")
            return ""
        return destino

    @Slot(str, str, result=str)
    def novoArquivo(self, pasta, nome):
        """Cria um arquivo vazio com o nome dado (ou "nome 2"...) e devolve o caminho, para a janela já renomear."""
        caminho = os.path.join(pasta, nome)
        if os.path.lexists(caminho):
            caminho = self._nome_livre(pasta, nome)
        try:
            with open(caminho, "x", encoding="utf-8"):
                pass
        except OSError:
            self.aviso.emit("Não foi possível criar o arquivo aqui.")
            return ""
        return caminho

    @Slot("QVariantList", result=str)
    def moverParaNovaPasta(self, caminhos):
        """Cria uma pasta ao lado dos itens e põe todos dentro. Devolve a pasta, para a janela já renomear."""
        if not caminhos:
            return ""
        pasta = self.novaPasta(os.path.dirname(caminhos[0]))
        if not pasta:
            return ""
        for caminho in caminhos:
            try:
                os.rename(caminho, os.path.join(pasta, os.path.basename(caminho)))
            except OSError:
                self.aviso.emit(f"Não foi possível mover \"{os.path.basename(caminho)}\".")
        return pasta

    # ------------------------------------------------------------ ações do menu que usam outros programas

    @Slot(str, result=bool)
    def temComando(self, nome):
        """Diz se um programa existe, para o menu só mostrar o que funciona neste sistema."""
        return shutil.which(nome) is not None

    @Slot(str)
    def novaJanela(self, pasta):
        soltar([sys.executable, os.path.join(AQUI, "bmos-arquivos.py"), pasta])

    @Slot(str)
    def copiarTexto(self, texto):
        QGuiApplication.clipboard().setText(texto)

    @Slot("QVariantList", str)
    def compactar(self, caminhos, formato):
        """Compacta com o Ark. Com formato ("zip", "tar.gz") o arquivo sai ao lado dos itens,
        com o nome deles. Sem formato, o Ark pergunta o nome e o tipo."""
        if not caminhos:
            return
        opcoes = ["--autofilename", formato] if formato else ["--dialog"]
        soltar(["ark", "--changetofirstpath", "--add"] + opcoes + list(caminhos))

    @Slot("QVariantList", bool)
    def extrair(self, caminhos, perguntar):
        """Extrai com o Ark: aqui mesmo, numa subpasta quando o arquivo tem vários itens, ou onde a pessoa escolher."""
        if not caminhos:
            return
        opcoes = ["--dialog"] if perguntar else ["--autosubfolder"]
        soltar(["ark", "--batch", "--autodestination"] + opcoes + list(caminhos))

    @Slot(str)
    def usoDoDisco(self, pasta):
        soltar(["filelight", pasta])

    @Slot(str)
    def propriedades(self, caminho):
        """Abre a janela de propriedades do Plasma: tamanho, permissões, com que app abre."""
        soltar(["kioclient", "openProperties", caminho])

    @Slot(str)
    def abrirNoDolphin(self, caminho):
        if os.path.isdir(caminho):
            soltar(["dolphin", "--new-window", caminho])
        else:
            soltar(["dolphin", "--new-window", "--select", caminho])

    @Slot(result="QVariantList")
    def coresDePasta(self):
        """Cores que o tema de ícones oferece para pastas."""
        return [{"nome": nome, "icone": icone} for nome, icone in CORES_DE_PASTA if QIcon.hasThemeIcon(icone)]

    @Slot(str, str)
    def corDaPasta(self, pasta, icone):
        """Grava (ou tira, com icone vazio) o ícone da pasta no .directory dela, como o Dolphin faz."""
        marca = os.path.join(pasta, MARCA_DA_PASTA)
        try:
            with open(marca, encoding="utf-8", errors="replace") as arquivo:
                linhas = [l.rstrip("\n") for l in arquivo if not l.startswith("Icon=")]
        except OSError:
            linhas = []
        if "[Desktop Entry]" not in linhas:
            linhas.insert(0, "[Desktop Entry]")
        if icone:
            linhas.insert(linhas.index("[Desktop Entry]") + 1, f"Icon={icone}")
        try:
            if [l for l in linhas if l.strip()] == ["[Desktop Entry]"]:
                # Sem cor e sem mais nada guardado, o arquivo não precisa existir.
                if os.path.exists(marca):
                    os.remove(marca)
            else:
                with open(marca, "w", encoding="utf-8") as arquivo:
                    arquivo.write("\n".join(linhas) + "\n")
        except OSError:
            self.aviso.emit("Não foi possível mudar a cor desta pasta.")
            return
        # A pasta de cima não muda quando o .directory muda: a janela é avisada à mão.
        self.pastaMudou.emit(os.path.dirname(pasta))

    # ------------------------------------------------------------ copiar, mover e colar

    def _ver_area(self):
        dados = QGuiApplication.clipboard().mimeData()
        pode = bool(dados) and (dados.hasFormat(COPIADOS) or any(u.isLocalFile() for u in dados.urls()))
        if pode != self._pode_colar:
            self._pode_colar = pode
            self.areaMudou.emit()

    @Slot("QVariantList", bool)
    def copiar(self, caminhos, recortar):
        """Copiar (ou recortar) para a área de transferência, no formato dos outros gerenciadores."""
        enderecos = [QUrl.fromLocalFile(c) for c in caminhos]
        dados = QMimeData()
        dados.setUrls(enderecos)
        texto = ("cut" if recortar else "copy") + "\n" + "\n".join(u.toString() for u in enderecos)
        dados.setData(COPIADOS, texto.encode())
        if recortar:
            dados.setData(RECORTE_KDE, b"1")
        QGuiApplication.clipboard().setMimeData(dados)

    @Slot(str)
    def colar(self, destino):
        dados = QGuiApplication.clipboard().mimeData()
        if not dados:
            return
        mover, caminhos = False, []
        if dados.hasFormat(COPIADOS):
            linhas = bytes(dados.data(COPIADOS)).decode(errors="replace").splitlines()
            mover = bool(linhas) and linhas[0].strip() == "cut"
            caminhos = [para_caminho(l.strip()) for l in linhas[1:] if l.strip().startswith("file://")]
        else:
            caminhos = [u.toLocalFile() for u in dados.urls() if u.isLocalFile()]
            mover = dados.hasFormat(RECORTE_KDE) and bytes(dados.data(RECORTE_KDE)) == b"1"
        if caminhos:
            if mover:
                QGuiApplication.clipboard().clear()
            self._iniciar(caminhos, destino, mover)

    @Slot("QVariantList", str)
    def moverPara(self, caminhos, destino):
        self._iniciar([para_caminho(c) for c in caminhos], destino, True)

    @Slot("QVariantList", str)
    def copiarPara(self, caminhos, destino):
        self._iniciar([para_caminho(c) for c in caminhos], destino, False)

    @Slot("QVariantList", str)
    def soltar(self, enderecos, destino):
        """Itens arrastados e soltos numa pasta: move no mesmo disco e copia para outro disco, como no Mac."""
        caminhos = [para_caminho(str(e.toString() if hasattr(e, "toString") else e)) for e in enderecos]
        caminhos = [c for c in caminhos if c.startswith("/") and os.path.lexists(c)]
        if not caminhos:
            return
        if destino == "lixeira:":
            self.paraLixeira(caminhos)
            return
        try:
            mesmo_disco = os.stat(caminhos[0]).st_dev == os.stat(destino).st_dev
        except OSError:
            mesmo_disco = False
        self._iniciar(caminhos, destino, mesmo_disco)

    @Slot("QVariantList", result="QVariantList")
    def enderecos(self, caminhos):
        """Caminhos como endereços file://, para arrastar para outros apps."""
        return [QUrl.fromLocalFile(c).toString() for c in caminhos]

    @Slot("QVariantList")
    def duplicar(self, caminhos):
        if caminhos:
            self._iniciar(list(caminhos), os.path.dirname(caminhos[0]), False)

    def _definir_tarefa(self, ativa, texto="", fracao=0.0):
        self._tarefa = {"ativa": ativa, "texto": texto, "fracao": fracao}
        self.tarefaMudou.emit()

    def _iniciar(self, caminhos, destino, mover):
        if self._tarefa["ativa"]:
            self.aviso.emit("Espere a cópia atual terminar.")
            return
        if not os.path.isdir(destino) or not os.access(destino, os.W_OK):
            self.aviso.emit("Não é possível gravar nesta pasta.")
            return
        self._definir_tarefa(True, "Preparando…")
        threading.Thread(target=self._executar, args=(caminhos, destino, mover), daemon=True).start()

    def _executar(self, caminhos, destino, mover):
        falhas = 0
        for indice, origem in enumerate(caminhos):
            origem = origem.rstrip("/") or "/"
            nome = os.path.basename(origem)
            self._definir_tarefa(True, ("Movendo " if mover else "Copiando ") + nome, indice / len(caminhos))
            if not os.path.lexists(origem):
                falhas += 1
                continue
            mesma_pasta = os.path.dirname(origem) == destino
            if mesma_pasta and mover:
                continue
            if os.path.isdir(origem) and (destino == origem or destino.startswith(origem + "/")):
                self.aviso.emit("Uma pasta não pode ir para dentro dela mesma.")
                continue
            alvo = os.path.join(destino, nome)
            if mesma_pasta:
                alvo = self._nome_livre(destino, nome, copia=True)
            elif os.path.lexists(alvo):
                alvo = self._nome_livre(destino, nome)  # nunca substitui: mantém os dois
            try:
                if mover:
                    shutil.move(origem, alvo)
                elif os.path.isdir(origem) and not os.path.islink(origem):
                    shutil.copytree(origem, alvo, symlinks=True)
                else:
                    shutil.copy2(origem, alvo, follow_symlinks=False)
            except (OSError, shutil.Error) as erro:
                print(f"arquivos: {origem} -> {alvo}: {erro!r}", flush=True)
                falhas += 1
        self._definir_tarefa(False)
        if falhas:
            self.aviso.emit("Um item não pôde ser copiado." if falhas == 1 else f"{falhas} itens não puderam ser copiados.")
        self.pastaMudou.emit(destino)

    # ------------------------------------------------------------ lixeira

    @Slot("QVariantList")
    def paraLixeira(self, caminhos):
        def mandar():
            codigo, saida = rodar(["gio", "trash", "--"] + list(caminhos), 120)
            if codigo != 0:
                print(f"arquivos: lixeira: {saida.strip()}", flush=True)
                self.aviso.emit("Não foi possível mover para a Lixeira.")
            if caminhos:
                self.pastaMudou.emit(os.path.dirname(caminhos[0]))

        threading.Thread(target=mandar, daemon=True).start()

    @Slot("QVariantList")
    def restaurar(self, caminhos):
        """Devolve itens da Lixeira para a pasta de onde saíram (lida do .trashinfo de cada um)."""
        falhas = 0
        for caminho in caminhos:
            nome = os.path.basename(caminho)
            registro = os.path.join(LIXEIRA, "info", nome + ".trashinfo")
            try:
                with open(registro, encoding="utf-8") as arquivo:
                    achado = re.search(r"^Path=(.+)$", arquivo.read(), re.M)
                original = urllib.parse.unquote(achado.group(1)) if achado else ""
                if not original.startswith("/"):
                    raise OSError("sem caminho de origem")
                pasta = os.path.dirname(original)
                os.makedirs(pasta, exist_ok=True)
                if os.path.lexists(original):
                    original = self._nome_livre(pasta, os.path.basename(original))
                shutil.move(caminho, original)
                os.remove(registro)
            except OSError as erro:
                print(f"arquivos: restaurar {caminho}: {erro!r}", flush=True)
                falhas += 1
        if falhas:
            self.aviso.emit("Um item não pôde ser devolvido." if falhas == 1 else f"{falhas} itens não puderam ser devolvidos.")
        self.pastaMudou.emit("lixeira:")

    @Slot()
    def esvaziarLixeira(self):
        def esvaziar():
            rodar(["gio", "trash", "--empty"], 300)
            self.pastaMudou.emit("lixeira:")

        threading.Thread(target=esvaziar, daemon=True).start()
