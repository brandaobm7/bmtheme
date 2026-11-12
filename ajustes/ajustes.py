"""Ajustes do bmos: a parte que lê e grava os ajustes do sistema para a janela Ajustes.qml.

O Ajustes não guarda nada por conta própria. Cada ajuste é lido e gravado no mesmo
lugar que as Configurações do Sistema do Plasma usam (os mesmos arquivos, serviços
e comandos), então as duas telas sempre mostram o mesmo valor.

Como funciona:
- cada página tem uma função "ler_<página>" que devolve os valores e as listas de
  opções dela, por chave ("tela.resolucao", "som.volume"...);
- cada chave que pode ser mudada tem uma função em GRAVAR;
- a janela pede uma página, mostra o que veio e manda gravar o que a pessoa mudar.
As leituras rodam fora da linha principal, para a janela não travar.
"""

import glob
import json
import os
import re
import atexit
import shutil
import subprocess
import threading
import time

from PySide6.QtCore import Property, QObject, QTimer, Signal, Slot

from comum import rodar, soltar

# O comando do Qt que conversa com o Plasma muda de nome conforme a versão do Fedora.
QDBUS = next((c for c in ("qdbus6", "qdbus-qt6", "qdbus") if shutil.which(c)), "qdbus")

CASA = os.path.expanduser("~")
DADOS = os.environ.get("XDG_DATA_HOME") or os.path.join(CASA, ".local/share")
ESTADO = os.path.join(DADOS, "bmos-tema")
PERFIS = {"power-saver": "economico", "balanced": "alto", "performance": "game"}
PERFIS_DBUS = ("net.hadess.PowerProfiles", "org.freedesktop.UPower.PowerProfiles")
# Brilho da tela. Do Plasma 6.2 em diante existe um controle por tela (TELAS).
# O anterior (BRILHO) fica de reserva para as versões mais antigas.
TELAS = ("org.kde.ScreenBrightness", "/org/kde/ScreenBrightness")
BRILHO = ("org.kde.Solid.PowerManagement", "/org/kde/Solid/PowerManagement/Actions/BrightnessControl",
          "org.kde.Solid.PowerManagement.Actions.BrightnessControl")
MINUTOS = [("0", "Nunca"), ("1", "1 minuto"), ("2", "2 minutos"), ("5", "5 minutos"), ("10", "10 minutos"),
           ("15", "15 minutos"), ("30", "30 minutos"), ("60", "1 hora")]
# Fusos do Brasil primeiro. Os outros ficam nas Configurações do Sistema.
FUSOS = [("America/Sao_Paulo", "Brasília"), ("America/Manaus", "Manaus"), ("America/Cuiaba", "Cuiabá"),
         ("America/Campo_Grande", "Campo Grande"), ("America/Belem", "Belém"), ("America/Fortaleza", "Fortaleza"),
         ("America/Recife", "Recife"), ("America/Bahia", "Salvador"), ("America/Porto_Velho", "Porto Velho"),
         ("America/Boa_Vista", "Boa Vista"), ("America/Rio_Branco", "Rio Branco"),
         ("America/Noronha", "Fernando de Noronha"), ("Europe/Lisbon", "Lisboa"), ("UTC", "UTC")]


def opcoes(pares):
    return [{"id": ident, "nome": nome} for ident, nome in pares]


def config(arquivo, grupos, chave, padrao=""):
    """Lê uma chave de um arquivo de configuração do KDE."""
    comando = ["kreadconfig6", "--file", arquivo]
    for grupo in grupos:
        comando += ["--group", grupo]
    codigo, saida = rodar(comando + ["--key", chave, "--default", str(padrao)], 5)
    return saida if codigo == 0 else str(padrao)


def gravar_config(arquivo, grupos, chave, valor, avisar=False):
    comando = ["kwriteconfig6", "--file", arquivo]
    if avisar:
        comando.append("--notify")  # avisa na hora o programa que usa o arquivo
    for grupo in grupos:
        comando += ["--group", grupo]
    rodar(comando + ["--key", chave, str(valor)], 5)


def dbus(barramento, destino, caminho, interface, *resto):
    """Chama o busctl e devolve o valor da resposta, sem o tipo na frente."""
    codigo, saida = rodar(["busctl", barramento, *resto[:1], destino, caminho, interface, *resto[1:]], 6)
    if codigo != 0 or not saida:
        return None
    partes = saida.split(" ", 1)
    return partes[1].strip('"') if len(partes) > 1 else ""


# ====================================================================== tela

def tela_do_brilho():
    """Caminho da tela embutida no controle de brilho por tela, ou None se ele não existe."""
    codigo, saida = rodar(["busctl", "--user", "get-property", *TELAS, TELAS[0], "DisplaysDBusNames"], 5)
    nomes = re.findall(r'"([^"]+)"', saida) if codigo == 0 else []
    for nome in nomes:
        caminho = f"{TELAS[1]}/{nome}"
        if dbus("--user", TELAS[0], caminho, TELAS[0] + ".Display", "get-property", "IsInternal") == "true":
            return caminho
    return f"{TELAS[1]}/{nomes[0]}" if nomes else None


def brilho_da_tela():
    """(atual, máximo, caminho da tela). O caminho é None quando vale o controle antigo."""
    tela = tela_do_brilho()
    if tela:
        _, saida = rodar(["busctl", "--user", "get-property", TELAS[0], tela, TELAS[0] + ".Display",
                          "Brightness", "MaxBrightness"], 5)
        numeros = re.findall(r"^i (\d+)$", saida, re.M)
        if len(numeros) == 2 and int(numeros[1]) > 0:
            return int(numeros[0]), int(numeros[1]), tela
    atual, maximo = dbus("--user", *BRILHO, "call", "brightness"), dbus("--user", *BRILHO, "call", "brightnessMax")
    if atual and maximo and atual.isdigit() and maximo.isdigit() and int(maximo) > 0:
        return int(atual), int(maximo), None
    return None, None, None


def ler_brilho():
    """Só o brilho: é o que muda por fora do Ajustes, pelo teclado ou pela Central."""
    v = {"tela.temBrilho": False}
    if glob.glob("/sys/class/backlight/*"):
        atual, maximo, _ = brilho_da_tela()
        if maximo:
            v["tela.temBrilho"], v["tela.brilho"] = True, round(atual * 100 / maximo)
    return v, {}


def monitor():
    """O monitor principal ligado, como o kscreen-doctor descreve."""
    codigo, saida = rodar(["kscreen-doctor", "-j"], 8)
    try:
        saidas = json.loads(saida).get("outputs", []) if codigo == 0 else []
    except ValueError:
        saidas = []
    ligadas = [s for s in saidas if s.get("enabled") and s.get("connected")]
    return min(ligadas, key=lambda s: s.get("priority") or 99) if ligadas else None


def ler_tela():
    v, o = {"tela.temMonitor": False, **ler_brilho()[0]}, {}
    m = monitor()
    if m:
        modos = m.get("modes", [])
        atual = next((x for x in modos if x["id"] == m.get("currentModeId")), None)
        tamanhos = sorted({(x["size"]["width"], x["size"]["height"]) for x in modos}, reverse=True)
        o["tela.resolucao"] = opcoes((f"{w}x{h}", f"{w} × {h}") for w, h in tamanhos)
        if atual:
            w, h = atual["size"]["width"], atual["size"]["height"]
            v["tela.resolucao"] = f"{w}x{h}"
            # Taxas da resolução em uso. Duas taxas quase iguais (59,94 e 60) viram uma só.
            taxas = {}
            for x in modos:
                if (x["size"]["width"], x["size"]["height"]) == (w, h):
                    taxas.setdefault(round(x["refreshRate"]), x["id"])
            o["tela.taxa"] = opcoes((str(t), f"{t} Hz") for t in sorted(taxas, reverse=True))
            v["tela.taxa"] = str(round(atual["refreshRate"]))
        v["tela.escala"] = str(round(float(m.get("scale") or 1) * 100))
        o["tela.escala"] = opcoes((p, p + "%") for p in ("100", "125", "150", "200"))
        v["tela.temMonitor"] = True
    ativa = config("kwinrc", ["NightColor"], "Active", "false") == "true"
    modo = config("kwinrc", ["NightColor"], "Mode", "")
    v["tela.luz"] = "desligada" if not ativa else ("sempre" if modo == "Constant" else "anoitecer")
    o["tela.luz"] = opcoes([("desligada", "Desligada"), ("anoitecer", "Do anoitecer ao amanhecer"), ("sempre", "Sempre ligada")])
    # Descanso: bloqueio da tela, apagar a tela e suspender.
    trava = config("kscreenlockerrc", ["Daemon"], "Autolock", "true") == "true"
    v["tela.bloquear"] = config("kscreenlockerrc", ["Daemon"], "Timeout", "5") if trava else "0"
    apaga = config("powerdevilrc", ["AC", "Display"], "TurnOffDisplayWhenIdle", "true") == "true"
    v["tela.apagar"] = str(int(config("powerdevilrc", ["AC", "Display"], "TurnOffDisplayIdleTimeoutSec", "600")) // 60) if apaga else "0"
    dorme = config("powerdevilrc", ["AC", "SuspendAndShutdown"], "AutoSuspendAction", "1") != "0"
    v["tela.suspender"] = str(int(config("powerdevilrc", ["AC", "SuspendAndShutdown"], "AutoSuspendIdleTimeoutSec", "900")) // 60) if dorme else "0"
    for chave in ("tela.bloquear", "tela.apagar", "tela.suspender"):
        o[chave] = opcoes(MINUTOS)
        if v[chave] not in dict(MINUTOS):   # um tempo que não está na lista aparece como está
            o[chave] = opcoes(MINUTOS + [(v[chave], v[chave] + " minutos")])
    return v, o


def aplicar_modo(resolucao=None, taxa=None):
    """Troca a resolução ou a taxa do monitor principal. Devolve o modo que estava em uso."""
    m = monitor()
    if not m:
        return None
    modos = m.get("modes", [])
    atual = next((x for x in modos if x["id"] == m.get("currentModeId")), None)
    if not atual:
        return None
    w, h = (int(n) for n in resolucao.split("x")) if resolucao else (atual["size"]["width"], atual["size"]["height"])
    candidatos = [x for x in modos if (x["size"]["width"], x["size"]["height"]) == (w, h)]
    if not candidatos:
        return None
    # A taxa pedida, ou a mais próxima da que estava em uso.
    alvo = float(taxa) if taxa else atual["refreshRate"]
    novo = min(candidatos, key=lambda x: abs(x["refreshRate"] - alvo))
    if novo["id"] == atual["id"]:
        return None
    rodar(["kscreen-doctor", f"output.{m['name']}.mode.{novo['id']}"], 15)
    return m["name"], atual["id"]


def energia(chave_tempo, chave_liga, grupo, minutos, ligado, desligado):
    """Grava um tempo de descanso para o computador na tomada e na bateria."""
    for fonte in ("AC", "Battery"):
        if minutos == "0":
            gravar_config("powerdevilrc", [fonte, grupo], chave_liga, desligado)
        else:
            gravar_config("powerdevilrc", [fonte, grupo], chave_liga, ligado)
            gravar_config("powerdevilrc", [fonte, grupo], chave_tempo, int(minutos) * 60)
    rodar(["busctl", "--user", "call", "org.kde.Solid.PowerManagement", "/org/kde/Solid/PowerManagement",
           "org.kde.Solid.PowerManagement", "refreshStatus"], 5)


def gravar_luz(valor):
    if valor == "desligada":
        gravar_config("kwinrc", ["NightColor"], "Active", "false", avisar=True)
    else:
        if valor == "sempre":
            gravar_config("kwinrc", ["NightColor"], "Mode", "Constant", avisar=True)
        else:
            # Sem a chave, vale o modo padrão do Plasma, que segue o pôr e o nascer do sol.
            rodar(["kwriteconfig6", "--notify", "--file", "kwinrc", "--group", "NightColor", "--key", "Mode", "--delete"], 5)
        gravar_config("kwinrc", ["NightColor"], "Active", "true", avisar=True)


def gravar_bloqueio(minutos):
    gravar_config("kscreenlockerrc", ["Daemon"], "Autolock", "false" if minutos == "0" else "true")
    if minutos != "0":
        gravar_config("kscreenlockerrc", ["Daemon"], "Timeout", minutos)
    rodar(["busctl", "--user", "call", "org.freedesktop.ScreenSaver", "/ScreenSaver", "org.kde.screensaver", "configure"], 5)


def gravar_brilho(valor):
    # A mudança mostra o aviso de brilho do Plasma, como a tecla do teclado.
    _, maximo, tela = brilho_da_tela()
    if maximo:
        alvo = str(round(maximo * max(1, min(100, int(valor))) / 100))
        if tela:
            rodar(["busctl", "--user", "call", TELAS[0], tela, TELAS[0] + ".Display", "SetBrightness", "iu", alvo, "0"], 5)
        else:
            rodar(["busctl", "--user", "call", *BRILHO, "setBrightness", "i", alvo], 5)


def gravar_escala(valor):
    m = monitor()
    if m:
        rodar(["kscreen-doctor", f"output.{m['name']}.scale.{int(valor) / 100:g}"], 15)


# ====================================================================== som

def aparelhos_de_som(tipo):
    codigo, saida = rodar(["pactl", "-f", "json", "list", tipo], 6)
    try:
        return json.loads(saida) if codigo == 0 else []
    except ValueError:
        return []


def nome_do_som(aparelho, reserva):
    """Nome legível de uma saída ou entrada de som. Alguns aparelhos vêm sem descrição."""
    extras = aparelho.get("properties") or {}
    for nome in (aparelho.get("description"), extras.get("device.description"), extras.get("device.product.name"),
                 extras.get("alsa.card_name"), extras.get("node.nick")):
        if nome and nome != "(null)":
            return nome
    return reserva


def volume_de(aparelho):
    canais = list((aparelho.get("volume") or {}).values())
    return int(str(canais[0].get("value_percent", "0")).rstrip("%")) if canais else 0


def ler_som():
    v, o = {"som.temSaida": False, "som.temEntrada": False}, {}
    saidas = aparelhos_de_som("sinks")
    entradas = [e for e in aparelhos_de_som("sources") if not e.get("name", "").endswith(".monitor")]
    _, saida_padrao = rodar(["pactl", "get-default-sink"], 5)
    _, entrada_padrao = rodar(["pactl", "get-default-source"], 5)
    for prefixo, lista, padrao, tem, reserva in (
            ("som.saida", saidas, saida_padrao, "som.temSaida", "Alto-falantes"),
            ("som.entrada", entradas, entrada_padrao, "som.temEntrada", "Microfone")):
        o[prefixo] = opcoes((a["name"], nome_do_som(a, reserva)) for a in lista)
        atual = next((a for a in lista if a["name"] == padrao), lista[0] if lista else None)
        if atual:
            v[tem], v[prefixo] = True, atual["name"]
            v[prefixo + "Volume"], v[prefixo + "Mudo"] = min(100, volume_de(atual)), bool(atual.get("mute"))
    return v, o


# ====================================================================== aparência

def fundos():
    """Papéis de parede instalados: os da pessoa primeiro, depois os do sistema."""
    lista = []
    for base in (os.path.join(DADOS, "wallpapers"), "/usr/share/wallpapers"):
        for pasta in sorted(glob.glob(os.path.join(base, "*"))):
            nome = os.path.basename(pasta)
            if nome == "bmos-bloqueio" or not os.path.isdir(pasta):
                continue
            # Só os formatos que a janela sabe mostrar. Alguns pacotes do Fedora vêm em JPEG XL.
            imagens = sorted((i for i in glob.glob(os.path.join(pasta, "contents", "images", "*"))
                              if i.lower().endswith((".png", ".jpg", ".jpeg", ".webp"))), key=os.path.getsize)
            previa = os.path.join(pasta, "contents", "screenshot.png")
            if not imagens:
                continue
            # A menor imagem do pacote serve de miniatura, para a grade abrir rápido.
            lista.append({"id": pasta, "nome": nome, "imagem": previa if os.path.exists(previa) else imagens[0]})
    return lista


def fundo_atual():
    roteiro = ('var d = desktops()[0]; d.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"]; '
               'print(d.readConfig("Image", ""))')
    _, saida = rodar([QDBUS, "org.kde.plasmashell", "/PlasmaShell", "org.kde.PlasmaShell.evaluateScript", roteiro], 6)
    return saida.replace("file://", "").rstrip("/")


def ler_aparencia():
    try:
        with open(os.path.join(CASA, ".config/bmos/tema"), encoding="utf-8") as arquivo:
            modo = "escuro" if arquivo.read().strip() == "escuro" else "claro"
    except OSError:
        modo = "claro"
    lista = fundos()
    atual = fundo_atual()
    # O Plasma guarda o pacote ou a imagem de dentro dele: vale o pacote que contém o caminho.
    escolhido = next((f["id"] for f in lista if atual == f["id"] or atual.startswith(f["id"] + "/")), "")
    return ({"aparencia.modo": modo, "aparencia.fundo": escolhido},
            {"aparencia.modo": opcoes([("claro", "Claro"), ("escuro", "Escuro")]), "aparencia.fundo": lista})


# ====================================================================== perfis

def servico_de_perfis():
    for nome in PERFIS_DBUS:
        caminho = "/" + nome.replace(".", "/")
        valor = dbus("--system", nome, caminho, nome, "get-property", "ActiveProfile")
        if valor is not None:
            return nome, caminho, valor
    return None, None, None


def ler_perfis():
    servico, caminho, valor = servico_de_perfis()
    v, o = {"perfis.tem": valor is not None, "perfis.perfil": PERFIS.get(valor or "", "alto")}, {}
    disponiveis = ""
    if servico:
        _, disponiveis = rodar(["busctl", "--system", "get-property", servico, caminho, servico, "Profiles"], 6)
    nomes = {"economico": "Econômico", "alto": "Alto", "game": "Game"}
    o["perfis.perfil"] = opcoes((nosso, nomes[nosso]) for deles, nosso in PERFIS.items() if f'"{deles}"' in disponiveis)
    for pasta in sorted(glob.glob("/sys/class/power_supply/BAT*")):
        try:
            with open(os.path.join(pasta, "capacity"), encoding="utf-8") as arquivo:
                carga = arquivo.read().strip()
            with open(os.path.join(pasta, "status"), encoding="utf-8") as arquivo:
                carregando = arquivo.read().strip() in ("Charging", "Full")
            v["perfis.bateria"] = carga + "%" + (", na tomada" if carregando else "")
            break
        except OSError:
            continue
    return v, o


def gravar_perfil(valor):
    servico, caminho, _ = servico_de_perfis()
    alvo = {v: k for k, v in PERFIS.items()}.get(valor)
    if servico and alvo:
        rodar(["busctl", "--system", "set-property", servico, caminho, servico, "ActiveProfile", "s", alvo], 6)


# ====================================================================== redes sem fio

def campos_nmcli(linha):
    """Separa uma linha do "nmcli -t", que escapa os dois-pontos do texto com barra."""
    return [c.replace("\\:", ":").replace("\\\\", "\\") for c in re.split(r"(?<!\\):", linha)]


def ler_wifi_rapido():
    """Se há placa e se está ligada. Sai antes da lista de redes, que demora a chegar."""
    _, aparelhos = rodar(["nmcli", "-t", "-f", "TYPE", "device"], 6)
    tem = "wifi" in aparelhos.splitlines()
    _, radio = rodar(["nmcli", "-t", "-f", "WIFI", "general"], 6)
    return {"wifi.tem": tem, "wifi.ligado": tem and radio == "enabled"}, {}


def ler_wifi():
    v = {**ler_wifi_rapido()[0], "wifi.redes": []}
    if v["wifi.ligado"]:
        _, salvas = rodar(["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"], 6)
        conhecidas = {campos_nmcli(l)[0] for l in salvas.splitlines() if l.endswith("wireless")}
        _, saida = rodar(["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", "auto"], 20)
        vistas = {}
        for linha in saida.splitlines():
            campos = campos_nmcli(linha)
            if len(campos) < 4 or not campos[1]:
                continue
            rede = {"ssid": campos[1], "sinal": int(campos[2] or 0), "segura": campos[3] not in ("", "--"),
                    "conectada": campos[0] == "*", "conhecida": campos[1] in conhecidas}
            antiga = vistas.get(rede["ssid"])
            # A mesma rede aparece uma vez por antena: fica a conectada, ou a de sinal mais forte.
            if not antiga or rede["conectada"] or (not antiga["conectada"] and rede["sinal"] > antiga["sinal"]):
                vistas[rede["ssid"]] = rede
        v["wifi.redes"] = sorted(vistas.values(), key=lambda r: (not r["conectada"], -r["sinal"]))
    return v, {}


# ====================================================================== bluetooth

def ler_bluetooth():
    _, estado = rodar(["bluetoothctl", "show"], 6)
    v = {"bluetooth.tem": "Powered:" in estado, "bluetooth.ligado": "Powered: yes" in estado, "bluetooth.aparelhos": []}
    if v["bluetooth.ligado"]:
        _, saida = rodar(["bluetoothctl", "devices"], 6)
        for linha in saida.splitlines():
            partes = linha.split(" ", 2)
            if len(partes) == 3 and partes[0] == "Device":
                _, info = rodar(["bluetoothctl", "info", partes[1]], 6)
                v["bluetooth.aparelhos"].append({"mac": partes[1], "nome": partes[2], "conectado": "Connected: yes" in info,
                                                 "pareado": "Paired: yes" in info})
        v["bluetooth.aparelhos"].sort(key=lambda a: (not a["conectado"], a["nome"].lower()))
    return v, {}


# ====================================================================== atualizações

def ler_atualizacoes():
    v = {"atualizacoes.tem": shutil.which("rpm-ostree") is not None}
    codigo, saida = rodar(["rpm-ostree", "status", "--json"], 20)
    try:
        implantacoes = json.loads(saida).get("deployments", []) if codigo == 0 else []
    except ValueError:
        implantacoes = []
    em_uso = next((d for d in implantacoes if d.get("booted")), None)
    pronta = next((d for d in implantacoes if d.get("staged")), None)

    def descrever(d):
        dia = time.strftime("%d/%m/%Y", time.localtime(d.get("timestamp", 0)))
        return f"{d.get('version', '')}, de {dia}"

    v["atualizacoes.sistema"] = descrever(em_uso) if em_uso else "Não foi possível ler"
    v["atualizacoes.pronta"] = descrever(pronta) if pronta else ""
    v["atualizacoes.automaticas"] = rodar(["systemctl", "is-enabled", "uupd.timer"], 5)[1] == "enabled" \
        or rodar(["systemctl", "is-enabled", "rpm-ostreed-automatic.timer"], 5)[1] == "enabled"
    v["atualizacoes.temFlatpak"] = shutil.which("flatpak") is not None
    if v["atualizacoes.temFlatpak"]:
        codigo, saida = rodar(["flatpak", "remote-ls", "--updates", "--columns=application"], 40)
        v["atualizacoes.apps"] = (str(len([l for l in saida.splitlines() if l.strip()])) if codigo == 0 else "?")
    return v, {}


# ====================================================================== hardware e sobre

def primeira(arquivo, prefixo):
    try:
        with open(arquivo, encoding="utf-8", errors="replace") as leitura:
            for linha in leitura:
                if linha.startswith(prefixo):
                    return linha.split(":" if ":" in linha else "=", 1)[1].strip().strip('"')
    except OSError:
        pass
    return ""


def ler_hardware():
    v = {"hardware.processador": primeira("/proc/cpuinfo", "model name"),
         "hardware.nucleos": str(os.cpu_count() or "")}
    memoria = primeira("/proc/meminfo", "MemTotal").split(" ")[0]
    # O sistema enxerga um pouco menos do que o que está instalado: arredonda para o GB cheio.
    v["hardware.memoria"] = f"{round(int(memoria) / 1e6)} GB" if memoria.isdigit() else ""
    _, placas = rodar(["lspci"], 6)
    v["hardware.video"] = [re.sub(r"\s*\(rev [0-9a-f]+\)$", "", l.split(": ", 1)[1])
                           for l in placas.splitlines() if re.search(r"VGA|3D controller", l) and ": " in l]
    try:
        disco = shutil.disk_usage(CASA)
        v["hardware.disco"] = f"{round(disco.free / 1e9)} GB livres de {round(disco.total / 1e9)} GB"
    except OSError:
        v["hardware.disco"] = ""
    m = monitor()
    atual = next((x for x in m.get("modes", []) if x["id"] == m.get("currentModeId")), None) if m else None
    v["hardware.tela"] = f"{atual['size']['width']} × {atual['size']['height']}, {round(atual['refreshRate'])} Hz" if atual else ""
    return v, {}


def ler_sobre():
    try:
        with open(os.path.join(ESTADO, "instalado"), encoding="utf-8") as arquivo:
            tema = arquivo.read().strip()
    except OSError:
        tema = ""
    # O Bazzite põe a versão no fim do nome da imagem: "bazzite-nvidia-42.20251018".
    imagem = (primeira("/etc/os-release", "IMAGE_ID") or primeira("/etc/os-release", "VERSION_ID")).rsplit("-", 1)[-1]
    _, plasma = rodar(["plasmashell", "--version"], 6)
    return {"sobre.tema": tema or "em desenvolvimento",
            "sobre.sistema": (primeira("/etc/os-release", "PRETTY_NAME") + " " + imagem).strip(),
            "sobre.plasma": plasma.replace("plasmashell", "").strip(),
            "sobre.kernel": os.uname().release}, {}


def ler_data():
    _, saida = rodar(["timedatectl", "show"], 6)
    campos = dict(l.split("=", 1) for l in saida.splitlines() if "=" in l)
    fuso = campos.get("Timezone", "")
    lista = FUSOS if fuso in dict(FUSOS) else FUSOS + [(fuso, fuso)]
    return ({"data.fuso": fuso, "data.automatica": campos.get("NTP") == "yes",
             "data.agora": time.strftime("%d/%m/%Y, %H:%M")}, {"data.fuso": opcoes(lista)})


LER = {"wifi": ler_wifi, "bluetooth": ler_bluetooth, "tela": ler_tela, "som": ler_som, "aparencia": ler_aparencia,
       "perfis": ler_perfis, "atualizacoes": ler_atualizacoes, "hardware": ler_hardware, "data": ler_data,
       "sobre": ler_sobre}

# Parte de uma página que sai na hora, antes da leitura completa.
LER_RAPIDO = {"wifi": ler_wifi_rapido}
# O que acompanhar por fora do Ajustes: o comando que avisa das mudanças e o que ler de novo.
VIGIAS = [
    (["pactl", "subscribe"], re.compile(r"on (sink|source|server) "), "som"),
    (["busctl", "--user", "monitor",
      "--match", "type='signal',interface='org.kde.ScreenBrightness',member='BrightnessChanged'",
      "--match", f"type='signal',interface='{BRILHO[2]}',member='brightnessChanged'"],
     re.compile(r"Type=signal"), "brilho"),
]

GRAVAR = {
    "tela.escala": gravar_escala,
    "tela.brilho": gravar_brilho,
    "tela.luz": gravar_luz,
    "tela.bloquear": gravar_bloqueio,
    "tela.apagar": lambda m: energia("TurnOffDisplayIdleTimeoutSec", "TurnOffDisplayWhenIdle", "Display", m, "true", "false"),
    "tela.suspender": lambda m: energia("AutoSuspendIdleTimeoutSec", "AutoSuspendAction", "SuspendAndShutdown", m, "1", "0"),
    "som.saida": lambda nome: rodar(["pactl", "set-default-sink", nome], 6),
    "som.saidaVolume": lambda n: (rodar(["pactl", "set-sink-mute", "@DEFAULT_SINK@", "0"], 5),
                                  rodar(["pactl", "set-sink-volume", "@DEFAULT_SINK@", f"{int(n)}%"], 5)),
    "som.saidaMudo": lambda sim: rodar(["pactl", "set-sink-mute", "@DEFAULT_SINK@", "1" if sim else "0"], 5),
    "som.entrada": lambda nome: rodar(["pactl", "set-default-source", nome], 6),
    "som.entradaVolume": lambda n: rodar(["pactl", "set-source-volume", "@DEFAULT_SOURCE@", f"{int(n)}%"], 5),
    "som.entradaMudo": lambda sim: rodar(["pactl", "set-source-mute", "@DEFAULT_SOURCE@", "1" if sim else "0"], 5),
    "aparencia.modo": lambda modo: rodar([os.path.join(CASA, ".local/bin/bmos-tema"), modo], 60),
    "aparencia.fundo": lambda pasta: rodar(["plasma-apply-wallpaperimage", pasta], 20),
    "perfis.perfil": gravar_perfil,
    "wifi.ligado": lambda sim: rodar(["nmcli", "radio", "wifi", "on" if sim else "off"], 10),
    "bluetooth.ligado": lambda sim: (rodar(["rfkill", "unblock", "bluetooth"], 5) if sim else None,
                                     rodar(["bluetoothctl", "power", "on" if sim else "off"], 10)),
    "data.fuso": lambda fuso: rodar(["timedatectl", "set-timezone", fuso], 60),
    "data.automatica": lambda sim: rodar(["timedatectl", "set-ntp", "true" if sim else "false"], 60),
}


class Ajustes(QObject):
    mudou = Signal()            # valores ou opções mudaram
    aviso = Signal(str)         # mensagem curta para a janela mostrar

    def __init__(self):
        super().__init__()
        self._valores, self._opcoes = {}, {}
        self._lidas = set()     # páginas que já tiveram uma leitura completa
        self._trava = threading.Lock()
        # Resolução ou taxa trocada, à espera de confirmação: (monitor, modo anterior).
        self._modo_anterior = None
        self._volta = QTimer(self)
        self._volta.setSingleShot(True)
        self._volta.setInterval(15000)
        self._volta.timeout.connect(self.desfazerModo)

    valores = Property("QVariantMap", lambda self: self._valores, notify=mudou)
    opcoes = Property("QVariantMap", lambda self: self._opcoes, notify=mudou)

    def _juntar(self, valores, lista_de_opcoes):
        with self._trava:
            self._valores = {**self._valores, **valores}
            self._opcoes = {**self._opcoes, **lista_de_opcoes}
        self.mudou.emit()

    def _ler(self, pagina):
        leitor = ler_brilho if pagina == "brilho" else LER.get(pagina)
        if leitor:
            try:
                rapido = LER_RAPIDO.get(pagina)
                if rapido and pagina not in self._lidas:
                    self._juntar(*rapido())
                self._juntar(*leitor())
                self._lidas.add(pagina)
            except Exception as erro:  # uma página com erro não derruba as outras
                print(f"ajustes: erro ao ler {pagina}: {erro}", flush=True)

    def vigiar(self):
        """Acompanha o volume e o brilho mudados por fora (teclado, Central), para a tela andar junto."""
        for comando, padrao, pagina in VIGIAS:
            threading.Thread(target=self._vigia, args=(comando, padrao, pagina), daemon=True).start()

    def _vigia(self, comando, padrao, pagina):
        # Sem o stdbuf, o aviso pode ficar preso na saída do comando até juntar muitos.
        if shutil.which("stdbuf"):
            comando = ["stdbuf", "-oL", *comando]
        # O setpriv faz o comando terminar junto com o Ajustes, mesmo se o Ajustes for derrubado.
        if shutil.which("setpriv"):
            comando = ["setpriv", "--pdeathsig", "TERM", *comando]
        try:
            # Em inglês: o texto dos avisos muda com o idioma do sistema.
            processo = subprocess.Popen(comando, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True,
                                        env={**os.environ, "LC_ALL": "C"})
        except OSError:
            return
        atexit.register(processo.terminate)
        espera = None
        for linha in processo.stdout:
            if not padrao.search(linha):
                continue
            # Arrastar uma barra gera muitos avisos seguidos: lê uma vez, logo depois do último.
            if espera:
                espera.cancel()
            espera = threading.Timer(0.06, self._ler, args=(pagina,))
            espera.daemon = True
            espera.start()

    @Slot(str)
    def atualizar(self, pagina):
        """Lê de novo os ajustes de uma página, fora da linha principal."""
        threading.Thread(target=self._ler, args=(pagina,), daemon=True).start()

    @Slot(str, "QVariant")
    def gravar(self, chave, valor):
        """Mostra o valor novo na hora, grava no sistema e confere o que ficou."""
        if chave in ("tela.resolucao", "tela.taxa"):
            self._trocar_modo(chave, valor)
            return
        gravador = GRAVAR.get(chave)
        if not gravador:
            return
        self._juntar({chave: valor}, {})

        def tarefa():
            try:
                gravador(valor)
            except Exception as erro:
                print(f"ajustes: erro ao gravar {chave}: {erro}", flush=True)
                self.aviso.emit("Não foi possível mudar este ajuste.")
            self._ler(chave.split(".")[0])

        threading.Thread(target=tarefa, daemon=True).start()

    # ---- resolução e taxa: a troca só fica se a pessoa confirmar

    def _trocar_modo(self, chave, valor):
        anterior = aplicar_modo(resolucao=valor) if chave == "tela.resolucao" else aplicar_modo(taxa=valor)
        if anterior:
            # Se a tela nova não aparecer, ninguém consegue clicar em nada: sem confirmação, volta sozinha.
            self._modo_anterior = self._modo_anterior or anterior
            self._juntar({"tela.confirmar": True}, {})
            self._volta.start()
        self._ler("tela")

    @Slot()
    def manterModo(self):
        self._volta.stop()
        self._modo_anterior = None
        self._juntar({"tela.confirmar": False}, {})

    @Slot()
    def desfazerModo(self):
        self._volta.stop()
        if self._modo_anterior:
            nome, modo = self._modo_anterior
            rodar(["kscreen-doctor", f"output.{nome}.mode.{modo}"], 15)
        self._modo_anterior = None
        self._juntar({"tela.confirmar": False}, {})
        self.atualizar("tela")

    # ---- redes sem fio e bluetooth

    @Slot(str, str)
    def conectarRede(self, ssid, senha):
        self._juntar({"wifi.conectando": ssid}, {})

        def tarefa():
            # A senha vai como argumento do nmcli, que é quem a guarda no sistema.
            comando = ["nmcli", "device", "wifi", "connect", ssid] + (["password", senha] if senha else [])
            codigo, _ = rodar(comando, 45)
            if codigo != 0:
                self.aviso.emit("Não foi possível conectar. Confira a senha." if senha else "Não foi possível conectar.")
            self._juntar({"wifi.conectando": ""}, {})
            self._ler("wifi")

        threading.Thread(target=tarefa, daemon=True).start()

    @Slot(str, bool)
    def ligarAparelho(self, mac, conectar):
        def tarefa():
            codigo, _ = rodar(["bluetoothctl", "connect" if conectar else "disconnect", mac], 25)
            if codigo != 0 and conectar:
                self.aviso.emit("Não foi possível conectar o aparelho.")
            self._ler("bluetooth")

        threading.Thread(target=tarefa, daemon=True).start()

    # ---- botões

    @Slot(str)
    def maisOpcoes(self, modulo):
        """Abre o módulo correspondente das Configurações do Sistema do Plasma."""
        soltar(["systemsettings", modulo] if modulo else ["systemsettings"])

    @Slot()
    def atualizarSistema(self):
        """Abre um terminal com o atualizador do Bazzite, que mostra o andamento."""
        for terminal, opcao in (("ptyxis", ["--"]), ("konsole", ["-e"]), ("gnome-terminal", ["--"])):
            if shutil.which(terminal):
                comando = "ujust update" if shutil.which("ujust") else "rpm-ostree upgrade"
                soltar([terminal] + opcao + ["bash", "-c", comando + "; echo; read -n 1 -s -r -p 'Pressione uma tecla para fechar.'"])
                return
        self.aviso.emit("Nenhum terminal conhecido foi encontrado.")

    @Slot()
    def reiniciar(self):
        """Pede ao Plasma a tela de reinício, que confirma antes."""
        rodar([QDBUS, "org.kde.LogoutPrompt", "/LogoutPrompt", "org.kde.LogoutPrompt.promptReboot"], 6)
