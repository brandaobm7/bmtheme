"""O que os apps do bmos (Arquivos e Ajustes) têm em comum: os ícones do tema para
o QML, o modo claro ou escuro, e a partida da janela.

Roda com o PySide6 do ambiente Python que o instalador do tema cria em
~/.local/share/bmos-tema/venv.
"""

import os
import subprocess
import sys
import urllib.parse

# Os controles do Qt Quick são desenhados pelas próprias telas, sem o estilo do sistema.
os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")

from PySide6.QtCore import Property, QFileSystemWatcher, QObject, QSize, QUrl, Signal, Slot
from PySide6.QtGui import QGuiApplication, QIcon, QPixmap
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuick import QQuickImageProvider

AQUI = os.path.dirname(os.path.realpath(__file__))
IMAGENS_DE_FUNDO = (".png", ".jpg", ".jpeg", ".webp")


def rodar(comando, tempo=15):
    """Roda um comando e devolve (código, saída). Nunca levanta exceção."""
    try:
        r = subprocess.run(comando, capture_output=True, text=True, timeout=tempo)
        return r.returncode, r.stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return 1, ""


def soltar(comando):
    """Inicia um programa e não espera por ele."""
    try:
        subprocess.Popen(comando, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        return True
    except OSError:
        return False


class Icones(QQuickImageProvider):
    """image://icone/NOME, do tema de ícones do sistema, ou image://icone//caminho/absoluto.png"""

    def __init__(self):
        super().__init__(QQuickImageProvider.ImageType.Pixmap)

    def requestPixmap(self, ident, tamanho, pedido):
        lado = max(pedido.width(), pedido.height(), 64)
        ident = urllib.parse.unquote(ident)  # o QML troca "|" e acentos por códigos (%7C)
        if ident.startswith("/") and os.path.exists(ident):
            candidatos = [QIcon(ident)]
        else:
            # Vários nomes separados por "|": vale o primeiro que o tema de ícones tiver.
            candidatos = [QIcon.fromTheme(nome) for nome in ident.split("|") if nome]
        candidatos += [QIcon.fromTheme("application-x-executable"),
                       QIcon(os.path.join(AQUI, "icones", "layout-grid-cinza.svg"))]
        pixmap = QPixmap()
        for icone in candidatos:
            pixmap = icone.pixmap(QSize(lado, lado))
            if not pixmap.isNull():
                break
        if tamanho is not None:
            tamanho.setWidth(pixmap.width())
            tamanho.setHeight(pixmap.height())
        return pixmap


class Sistema(QObject):
    """O pouco que as telas pedem ao sistema: o modo claro ou escuro e o papel de parede."""

    temaMudou = Signal()

    def __init__(self):
        super().__init__()
        # O bmos-tema grava aqui o modo em uso: "claro" ou "escuro".
        self._arquivo_do_tema = os.path.join(os.path.expanduser("~/.config/bmos"), "tema")
        self._escuro = self._ler_tema()
        self._vigia = QFileSystemWatcher(self)
        self._vigia.fileChanged.connect(self._tema_mudou)
        if os.path.exists(self._arquivo_do_tema):
            self._vigia.addPath(self._arquivo_do_tema)

    def _ler_tema(self):
        try:
            with open(self._arquivo_do_tema, encoding="utf-8") as arquivo:
                return arquivo.read().strip() == "escuro"
        except OSError:
            return False

    def _tema_mudou(self):
        # Alguns programas trocam o arquivo por outro em vez de reescrevê-lo: a vigia precisa ser refeita.
        if os.path.exists(self._arquivo_do_tema) and self._arquivo_do_tema not in self._vigia.files():
            self._vigia.addPath(self._arquivo_do_tema)
        novo = self._ler_tema()
        if novo != self._escuro:
            self._escuro = novo
            self.temaMudou.emit()

    @Property(bool, notify=temaMudou)
    def escuro(self):
        return self._escuro

    @Slot(str, result=bool)
    def usarComoPapel(self, caminho):
        """Usa uma imagem como papel de parede da área de trabalho do Plasma."""
        if not caminho.lower().endswith(IMAGENS_DE_FUNDO) or not os.path.isfile(caminho):
            return False
        return rodar(["plasma-apply-wallpaperimage", caminho], 20)[0] == 0


def abrir_janela(app_id, nome, icone, arquivo_qml, contexto):
    """Abre a janela de um app do bmos e fica nela até fechar.

    app_id liga a janela ao atalho .desktop de mesmo nome: é assim que a dock mostra
    o ícone certo e junta a janela ao botão do app. contexto é uma função que recebe
    o objeto Sistema e devolve o que mais a tela usa, por nome.
    """
    app = QGuiApplication(sys.argv)
    app.setDesktopFileName(app_id)
    app.setApplicationName(nome)
    app.setWindowIcon(QIcon.fromTheme(icone))
    motor = QQmlApplicationEngine()
    motor.addImageProvider("icone", Icones())
    sistema = Sistema()
    objetos = {"sistema": sistema,
               "pastaIcones": QUrl.fromLocalFile(os.path.join(AQUI, "icones")).toString() + "/"}
    objetos.update(contexto(sistema))
    for chave, valor in objetos.items():
        motor.rootContext().setContextProperty(chave, valor)
    motor.quit.connect(app.quit)
    motor.load(QUrl.fromLocalFile(arquivo_qml))
    if not motor.rootObjects():
        return 1
    codigo = app.exec()
    # O motor some antes dos objetos que a tela usa, para ela não chamar um objeto que já foi apagado.
    del motor
    return codigo
