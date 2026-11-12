"""Simula cliques na tela do Ajustes, sem mostrar janela e sem mexer no sistema.

No lugar do motor de verdade (ajustes.py) entra um de mentira, com valores fixos,
que só anota o que a tela pediu para gravar. O que se confere aqui são as peças:
barra lateral, lista suspensa, segmentos, interruptor, barra, botões, o que some
quando o computador não tem, redes e aparelhos.

Uso, com o tema instalado:
  ~/.local/share/bmos-tema/venv/bin/python -u testes/teste_ajustes.py ajustes
"""
import os, sys
os.environ["QT_QPA_PLATFORM"] = "offscreen"
os.environ["QT_QUICK_CONTROLS_STYLE"] = "Basic"
pasta = sys.argv[1]
comum = os.path.join(pasta, "..", "app-comum")
sys.path[:0] = [pasta, comum]
from PySide6.QtCore import Property, QObject, QPoint, QPointF, Qt, QUrl, Signal, Slot
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine, QQmlExpression
from PySide6.QtQuick import QQuickItem
from PySide6.QtTest import QTest
import comum as pecas

MINUTOS = [{"id": m, "nome": m + " min"} for m in ("0", "1", "2", "5", "10", "15")]


class MotorDeMentira(QObject):
    mudou = Signal()
    aviso = Signal(str)

    def __init__(self):
        super().__init__()
        self.gravados, self.lidas, self.abertos, self.redes, self.aparelhos, self.botoes = [], [], [], [], [], []
        self.v = {
            "tela.temMonitor": True, "tela.temBrilho": False, "tela.resolucao": "1920x1080", "tela.taxa": "60",
            "tela.escala": "100", "tela.luz": "desligada", "tela.bloquear": "5", "tela.apagar": "10", "tela.suspender": "15",
            "som.temSaida": True, "som.temEntrada": False, "som.saida": "a", "som.saidaVolume": 40, "som.saidaMudo": False,
            "aparencia.modo": "claro", "aparencia.fundo": "",
            "wifi.tem": True, "wifi.ligado": True,
            "wifi.redes": [{"ssid": "Casa", "sinal": 90, "segura": True, "conectada": True, "conhecida": True},
                           {"ssid": "Vizinho", "sinal": 60, "segura": True, "conectada": False, "conhecida": True}],
            "bluetooth.tem": True, "bluetooth.ligado": True,
            "bluetooth.aparelhos": [{"mac": "AA:BB", "nome": "Fone", "conectado": False, "pareado": True}],
        }
        self.o = {
            "tela.resolucao": [{"id": "1920x1080", "nome": "1920 × 1080"}, {"id": "1280x720", "nome": "1280 × 720"}],
            "tela.taxa": [{"id": "60", "nome": "60 Hz"}],
            "tela.escala": [{"id": p, "nome": p + "%"} for p in ("100", "125", "150", "200")],
            "tela.luz": [{"id": "desligada", "nome": "Desligada"}, {"id": "sempre", "nome": "Sempre ligada"}],
            "tela.bloquear": MINUTOS, "tela.apagar": MINUTOS, "tela.suspender": MINUTOS,
            "som.saida": [{"id": "a", "nome": "Alto-falantes"}, {"id": "b", "nome": "Fone"}],
            "aparencia.modo": [{"id": "claro", "nome": "Claro"}, {"id": "escuro", "nome": "Escuro"}],
            "aparencia.fundo": [],
        }

    valores = Property("QVariantMap", lambda self: self.v, notify=mudou)
    opcoes = Property("QVariantMap", lambda self: self.o, notify=mudou)

    @Slot(str)
    def atualizar(self, pagina): self.lidas.append(pagina)
    @Slot(str, "QVariant")
    def gravar(self, chave, valor):
        self.gravados.append((chave, valor)); self.v = {**self.v, chave: valor}; self.mudou.emit()
    @Slot(str)
    def maisOpcoes(self, modulo): self.abertos.append(modulo)
    @Slot(str, str)
    def conectarRede(self, ssid, senha): self.redes.append((ssid, senha))
    @Slot(str, bool)
    def ligarAparelho(self, mac, conectar): self.aparelhos.append((mac, conectar))
    @Slot()
    def atualizarSistema(self): self.botoes.append("atualizar")
    @Slot()
    def reiniciar(self): self.botoes.append("reiniciar")
    @Slot()
    def manterModo(self): self.botoes.append("manter")
    @Slot()
    def desfazerModo(self): self.botoes.append("desfazer")


app = QGuiApplication(sys.argv)
motor = QQmlApplicationEngine(); motor.addImageProvider("icone", pecas.Icones())
falso, sistema = MotorDeMentira(), pecas.Sistema(); ctx = motor.rootContext()
ctx.setContextProperty("ajustes", falso); ctx.setContextProperty("sistema", sistema)
ctx.setContextProperty("pastaIcones", QUrl.fromLocalFile(os.path.join(comum, "icones")).toString() + "/")
ctx.setContextProperty("paginaInicial", "tela")
motor.load(QUrl.fromLocalFile(os.path.join(pasta, "Ajustes.qml")))
raiz = motor.rootObjects()[0]
contexto = motor.contextForObject(raiz)
def js(expr):
    valor = QQmlExpression(contexto, raiz, expr).evaluate()
    return valor[0] if isinstance(valor, tuple) else valor
ok = lambda nome, cond: print(("ok   " if cond else "FALHA"), nome)
esq, sem = Qt.MouseButton.LeftButton, Qt.KeyboardModifier.NoModifier
def peca(nome, de=None):
    """Acha uma peça pelo nome, descendo pelos itens da tela (os criados por listas não aparecem no findChild)."""
    for filho in (de or raiz.contentItem()).childItems():
        if filho.objectName() == nome:
            return filho
        achado = peca(nome, filho)
        if achado is not None:
            return achado
    return None
def ponto(item, fx=0.5, fy=0.5, dx=0, dy=0):
    p = item.mapToScene(QPointF(item.width() * fx + dx, item.height() * fy + dy))
    return QPoint(round(p.x()), round(p.y()))
def clique(onde):
    QTest.mouseMove(raiz, onde); QTest.qWait(40); QTest.mouseClick(raiz, esq, sem, onde); QTest.qWait(250)
def pagina(nome, fim=False):
    clique(ponto(peca("pagina:" + nome))); QTest.qWait(250)
    if fim:
        js("rolagem.contentY = Math.max(0, rolagem.contentHeight - rolagem.height)"); QTest.qWait(150)

QTest.qWait(1200)
ok("abre na página pedida e manda ler os ajustes dela", js("janela.pagina") == "tela" and "tela" in falso.lidas)
ok("o que o computador não tem some (brilho)", peca("peca:tela.brilho").parentItem().isVisible() is False)
ok("o que ele tem aparece (resolução)", peca("peca:tela.resolucao").parentItem().isVisible() is True)
clique(ponto(peca("peca:tela.escala"), 1, 0.5, dx=-25)); ok("segmentos: escolher 200%", falso.gravados[-1] == ("tela.escala", "200"))
clique(ponto(peca("peca:tela.resolucao")))
clique(ponto(peca("peca:tela.resolucao"), 0.5, 1, dy=6 + 6 + 30 + 15)); ok("lista suspensa: escolher a segunda resolução", falso.gravados[-1] == ("tela.resolucao", "1280x720"))
clique(ponto(peca("peca:mais:kcm_kscreen"))); ok("botão Abrir chama o módulo das Configurações do Sistema", falso.abertos[-1] == "kcm_kscreen")
pagina("tela", fim=True)
clique(ponto(peca("peca:tela.suspender")))
antes = len(falso.gravados); alvo = peca("peca:tela.suspender")
# Perto do fim da janela, a lista abre para cima: a primeira opção fica acima da peça.
abre_para_cima = alvo.mapToScene(QPointF(0, alvo.height())).y() + 6 * 30 + 12 + 22 > raiz.height() - 56
clique(ponto(alvo, 0.5, 0, dy=-(6 + 6 * 30 + 6) + 6 + 15) if abre_para_cima else ponto(alvo, 0.5, 1, dy=6 + 6 + 15))
ok("lista suspensa no fim da janela: escolher Nunca", len(falso.gravados) == antes + 1 and falso.gravados[-1] == ("tela.suspender", "0")); print("     abriu para cima:", abre_para_cima)
clique(ponto(peca("mais"), 0.3)); ok("atalho Mais opções abre o módulo da página", falso.abertos[-1] == "kcm_kscreen")
pagina("som")
ok("barra lateral troca de página e manda ler", js("janela.pagina") == "som" and falso.lidas[-1] == "som")
ok("grupo que o computador não tem some (entrada de som)", peca("peca:som.entrada") is None or not peca("peca:som.entrada").parentItem().parentItem().parentItem().parentItem().isVisible())
clique(ponto(peca("peca:som.saidaMudo"))); ok("interruptor: ligar Sem som", falso.gravados[-1] == ("som.saidaMudo", True))
clique(ponto(peca("peca:som.saidaMudo"))); ok("interruptor: desligar de novo", falso.gravados[-1] == ("som.saidaMudo", False))
barra = peca("peca:som.saidaVolume")
QTest.mousePress(raiz, esq, sem, ponto(barra, 0.2)); QTest.qWait(60)
for f in (0.3, 0.45, 0.6, 0.7):
    QTest.mouseMove(raiz, ponto(barra, f)); QTest.qWait(40)
QTest.mouseRelease(raiz, esq, sem, ponto(barra, 0.7)); QTest.qWait(300)
volumes = [v for c, v in falso.gravados if c == "som.saidaVolume"]
ok("barra: arrastar o volume grava um valor alto", len(volumes) >= 1 and 70 <= int(volumes[-1]) <= 100); print("     volumes gravados:", volumes)
pagina("aparencia")
clique(ponto(peca("peca:aparencia.modo"), 1, 0.5, dx=-25)); ok("segmentos: modo escuro", falso.gravados[-1] == ("aparencia.modo", "escuro"))
pagina("wifi")
clique(ponto(peca("rede:Vizinho"))); ok("clicar numa rede conhecida conecta sem pedir senha", falso.redes[-1] == ("Vizinho", ""))
antes = len(falso.redes); clique(ponto(peca("rede:Casa"))); ok("clicar na rede já conectada não faz nada", len(falso.redes) == antes)
clique(ponto(peca("peca:wifi.ligado"))); ok("interruptor do Wi-Fi", falso.gravados[-1] == ("wifi.ligado", False))
ok("com o Wi-Fi desligado a lista de redes some", peca("rede:Casa") is None or not peca("rede:Casa").isVisible())
pagina("bluetooth")
clique(ponto(peca("aparelho:AA:BB"))); ok("botão Conectar do aparelho Bluetooth", falso.aparelhos[-1] == ("AA:BB", True))
pagina("sobre")
clique(ponto(peca("peca:mais:"))); ok("Sobre: abrir as Configurações do Sistema", falso.abertos[-1] == "")
sys.stdout.flush()
# Sai direto: desmontar a tela aqui só produziria avisos sem importância.
os._exit(0)
