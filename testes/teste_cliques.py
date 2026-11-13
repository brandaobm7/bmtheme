"""Simula cliques e movimentos do mouse na tela do Arquivos, sem mostrar janela:
marcar e desmarcar itens, clique no vazio, abrir e fechar o menu, Esc, o
submenu que abre ao parar o mouse, e a barra lateral (arrastar para reordenar,
menu, renomear, retirar e restaurar).

Abre uma pasta temporária com nove pastas dentro, para as posições dos cliques
não dependerem do que há na pasta pessoal.

Uso, com o tema instalado:
  ~/.local/share/bmos-tema/venv/bin/python -u testes/teste_cliques.py arquivos
"""
import os, sys
os.environ["QT_QPA_PLATFORM"] = "offscreen"
os.environ["QT_QUICK_CONTROLS_STYLE"] = "Basic"
pasta = sys.argv[1]
comum = os.path.join(pasta, "..", "app-comum")
sys.path[:0] = [pasta, comum]
from PySide6.QtCore import QPoint, Qt, QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine, QQmlExpression
from PySide6.QtTest import QTest
import comum as lancador
import arquivos as motor_do_arquivos
from arquivos import Arquivos
# A arrumação da barra lateral feita pelo teste vai para um arquivo à parte, e não para o da pessoa.
import tempfile
motor_do_arquivos.ARRUMACAO = os.path.join(tempfile.mkdtemp(prefix="bmos-arq-teste-"), "arquivos.json")
app = QGuiApplication(sys.argv)
motor = QQmlApplicationEngine(); motor.addImageProvider("icone", lancador.Icones())
arq, sis = Arquivos(), lancador.Sistema(); ctx = motor.rootContext()
ctx.setContextProperty("arquivos", arq); ctx.setContextProperty("sistema", sis)
ctx.setContextProperty("pastaIcones", QUrl.fromLocalFile(os.path.join(comum, "icones")).toString() + "/")
import shutil, tempfile
base = tempfile.mkdtemp(prefix="bmos-arq-", dir=os.path.expanduser("~"))
for i in range(9):
    os.mkdir(os.path.join(base, f"Pasta {i + 1}"))
ctx.setContextProperty("pastaInicial", base)
motor.load(QUrl.fromLocalFile(os.path.join(pasta, "Arquivos.qml")))
raiz = motor.rootObjects()[0]
contexto = motor.contextForObject(raiz)
def js(expr): return QQmlExpression(contexto, raiz, expr).evaluate()
if isinstance(js("1"), tuple):
    _js = js
    def js(expr): return _js(expr)[0]
ok = lambda nome, cond: print(("ok   " if cond else "FALHA"), nome)
esq, dir_ = Qt.MouseButton.LeftButton, Qt.MouseButton.RightButton
sem = Qt.KeyboardModifier.NoModifier
def clique(janela, botao, x, y):
    QTest.mouseMove(janela, QPoint(x, y)); QTest.qWait(40); QTest.mouseClick(janela, botao, sem, QPoint(x, y)); QTest.qWait(200)
def mover(janela, x, y):
    QTest.mouseMove(janela, QPoint(x - 3, y - 2)); QTest.qWait(30); QTest.mouseMove(janela, QPoint(x, y)); QTest.qWait(30)
QTest.qWait(1500)
print("     janela:", raiz.width(), "x", raiz.height(), "| itens:", js("janela.itens.length"), "| modo:", js("janela.modo"))
# As posições saem da própria janela, para o teste não depender das medidas da grade.
largura, tamanho = int(js("grade.cellWidth")), int(js("janela.tamanho"))
x0 = int(js("grade.itemAtIndex(0).mapToItem(null, 0, 0).x")); y0 = int(js("grade.itemAtIndex(0).mapToItem(null, 0, 0).y"))
item = (x0 + largura // 2, y0 + 11 + tamanho // 2)       # o meio do ícone do primeiro item
vazio = (850, 600); vazio2 = (700, 520)
clique(raiz, esq, *item); ok("clicar num item marca o item", js("janela.selecao.length") == 1)
clique(raiz, esq, *vazio); ok("clicar no vazio da grade limpa a seleção", js("janela.selecao.length") == 0)
# O espaço entre dois itens vizinhos é vazio: só o ícone e o nome contam como o item.
icone = item
nome = (x0 + largura // 2, y0 + tamanho + 24 + 8)        # o meio da primeira linha do nome dele
entre = (x0 + largura, icone[1])                          # a divisa com o vizinho, na altura do ícone
clique(raiz, esq, *icone); clique(raiz, esq, *entre)
ok("clicar entre dois itens da grade limpa a seleção, sem marcar o vizinho", js("janela.selecao.length") == 0)
clique(raiz, esq, *entre); ok("clicar entre dois itens, sem nada marcado, não marca nenhum", js("janela.selecao.length") == 0)
clique(raiz, esq, icone[0] + largura, icone[1]); vizinho = js("janela.selecao[0]")
clique(raiz, esq, *nome)
ok("clicar no ícone do vizinho e depois no nome do primeiro marca um de cada vez",
   vizinho is not None and js("janela.selecao.length") == 1 and js("janela.selecao[0]") != vizinho)
clique(raiz, esq, x0 + 6, icone[1]); ok("clicar na beirada da célula, longe do ícone, limpa a seleção", js("janela.selecao.length") == 0)
clique(raiz, esq, *vazio)
clique(raiz, esq, *item); clique(raiz, dir_, *vazio)
ok("botão direito no vazio abre o menu e limpa a seleção", js("menu.visible") is True and js("janela.selecao.length") == 0)
clique(raiz, esq, *vazio2); ok("clicar em outro lugar da pasta fecha o menu", js("menu.visible") is False)
clique(raiz, dir_, *item); ok("botão direito num item abre o menu dele", js("menu.visible") is True and js("janela.selecao.length") == 1)
clique(raiz, esq, *item); ok("clicar de novo no item fecha o menu e mantém o item marcado", js("menu.visible") is False and js("janela.selecao.length") == 1)
clique(raiz, dir_, *vazio); QTest.keyClick(raiz, Qt.Key.Key_Escape); QTest.qWait(150); ok("Esc fecha o menu", js("menu.visible") is False)
clique(raiz, esq, *item); clique(raiz, esq, item[0] + largura, item[1])
ok("clicar em outro item troca a seleção", js("janela.selecao.length") == 1)
QTest.mouseClick(raiz, esq, Qt.KeyboardModifier.ControlModifier, QPoint(*item)); QTest.qWait(200)
ok("Ctrl+clique soma à seleção", js("janela.selecao.length") == 2)
clique(raiz, esq, *vazio); ok("clicar no vazio limpa a seleção de vários", js("janela.selecao.length") == 0)
# modo lista
js("janela.modo = 'lista'"); QTest.qWait(300)
clique(raiz, esq, 600, 190); ok("lista: clicar numa linha marca", js("janela.selecao.length") == 1)
clique(raiz, esq, 600, 620); ok("lista: clicar no vazio limpa a seleção", js("janela.selecao.length") == 0)
js("janela.modo = 'icones'"); QTest.qWait(300)
# submenu ao parar o mouse
clique(raiz, dir_, *vazio)
nomes = [e.get("nome") for e in js("menu.entradas").toVariant()] if hasattr(js("menu.entradas"), "toVariant") else [e.get("nome") for e in js("menu.entradas")]
alturas = []; y = 8 + 6
for e in (js("menu.entradas").toVariant() if hasattr(js("menu.entradas"), "toVariant") else js("menu.entradas")):
    h = 9 if e.get("separador") else 30; alturas.append((e.get("nome"), y + h // 2)); y += h
pos = dict(alturas)
menu = js("menu"); sub = js("submenu")
mover(menu, 120, pos["Ordenar por"]); QTest.qWait(350); ok("parar o mouse em Ordenar por abre o submenu ao lado", js("submenu.visible") is True)
print("     submenu em x,y:", js("submenu.x - menu.x"), js("submenu.y - menu.y"), "| entradas:", js("submenu.entradas.length"))
mover(menu, 120, pos["Atualizar"]); QTest.qWait(450); ok("ir para uma opção sem seta fecha o submenu", js("submenu.visible") is False)
mover(menu, 120, pos["Criar novo"]); QTest.qWait(350); ok("parar em Criar novo abre o submenu dele", js("submenu.visible") is True and js("submenu.entradas.length") == 3)
mover(menu, 120, pos["Ordenar por"]); QTest.qWait(350)
clique(sub, esq, 120, 8 + 6 + 30 * 2 + 15); ok("clicar em Tamanho no submenu ordena e fecha tudo", js("janela.ordem") == "tamanho" and js("menu.visible") is False and js("submenu.visible") is False)
clique(raiz, dir_, *vazio); mover(menu, 120, pos["Ordenar por"]); QTest.qWait(350); clique(raiz, esq, *vazio2)
ok("com o submenu aberto, clicar na pasta fecha os dois", js("menu.visible") is False and js("submenu.visible") is False)

# ---------------------------------------------------------------- barra lateral
def entradas_do_menu():
    lista = js("menu.entradas")
    return lista.toVariant() if hasattr(lista, "toVariant") else lista
def linhas_do_menu():
    y, onde = 8 + 6, {}
    for e in entradas_do_menu():
        h = 9 if e.get("separador") else 30
        onde[e.get("nome")] = y + h // 2
        y += h
    return onde
def nomes(lista):
    valor = js("janela." + lista)
    valor = valor.toVariant() if hasattr(valor, "toVariant") else valor
    return [i["nome"] for i in valor]
def arrastar(x, y, passos):
    QTest.mouseMove(raiz, QPoint(x, y)); QTest.qWait(40)
    QTest.mousePress(raiz, esq, sem, QPoint(x, y)); QTest.qWait(60)
    feito = 0
    for _ in range(abs(passos) // 6):
        feito += 6 if passos > 0 else -6
        QTest.mouseMove(raiz, QPoint(x, y + feito)); QTest.qWait(15)
    QTest.mouseMove(raiz, QPoint(x, y + passos)); QTest.qWait(60)
    QTest.mouseRelease(raiz, esq, sem, QPoint(x, y + passos)); QTest.qWait(300)
# Posição das linhas na janela: margem da janela, começo da barra lateral, título e 34 px por linha.
fav = lambda i: (150, 56 + 54 + 28 + 16 + i * 34)
antes = nomes("favoritos"); n = len(antes)
# Os Locais vêm depois dos Favoritos: a posição depende de quantos favoritos há na hora.
loc = lambda j: (150, 56 + 54 + 28 + len(nomes("favoritos")) * 34 + 10 + 28 + 16 + j * 34)
print("     favoritos:", antes, "| locais:", nomes("locais"))
arrastar(*fav(1), 68)
depois = nomes("favoritos")
ok("arrastar um favorito duas posições para baixo", depois == [antes[0], antes[2], antes[3], antes[1]] + antes[4:]); print("    ", depois)
arrastar(*fav(3), -102)
ok("arrastar de volta para o topo", nomes("favoritos") == [antes[1], antes[0]] + antes[2:])
locais = nomes("locais")
arrastar(*loc(len(locais) - 1), -34 * (len(locais) - 1))
ok("arrastar a Lixeira para o topo dos Locais", nomes("locais") == [locais[-1]] + locais[:-1]); print("    ", nomes("locais"))
ok("o arrasto não muda o grupo dos Favoritos", len(nomes("favoritos")) == n)
clique(raiz, esq, *fav(2)); ok("clicar num favorito ainda abre a pasta", js("janela.caminho") != base)
clique(raiz, dir_, *fav(1))
ok("menu do favorito Recentes: sem nova janela nem propriedades", js("menu.visible") is True and "Retirar dos Favoritos" in linhas_do_menu() and "Propriedades" not in linhas_do_menu() and "Abrir em nova janela" not in linhas_do_menu())
clique(js("menu"), esq, 120, linhas_do_menu()["Retirar dos Favoritos"])
ok("retirar dos Favoritos tira o item e fecha o menu", "Recentes" not in nomes("favoritos") and len(nomes("favoritos")) == n - 1 and js("menu.visible") is False)
clique(raiz, dir_, *fav(1))
ok("menu de um favorito que é pasta: nova janela, renomear, retirar e propriedades", all(x in linhas_do_menu() for x in ("Abrir", "Abrir em nova janela", "Renomear", "Retirar dos Favoritos", "Propriedades")))
alvo = nomes("favoritos")[1]
clique(js("menu"), esq, 120, linhas_do_menu()["Renomear"]); QTest.qWait(300)
ok("renomear abre o campo na própria linha", js("janela.renomeandoLateral") != "")
for letra in "Meu lugar":
    QTest.keyClick(raiz, letra); QTest.qWait(15)
QTest.qWait(100); QTest.keyClick(raiz, Qt.Key.Key_Return); QTest.qWait(300)
ok("o nome novo aparece na barra lateral", nomes("favoritos")[1] == "Meu lugar" and js("janela.renomeandoLateral") == ""); print("    ", alvo, "->", nomes("favoritos")[1])
clique(raiz, dir_, *loc(0))
ok("menu da Lixeira nos Locais: renomear e esvaziar, sem retirar", "Renomear" in linhas_do_menu() and "Esvaziar Lixeira" in linhas_do_menu() and "Retirar dos Favoritos" not in linhas_do_menu())
QTest.keyClick(raiz, Qt.Key.Key_Escape); QTest.qWait(150)
clique(raiz, dir_, 150, 56 + 600)
ok("botão direito no vazio da barra lateral oferece restaurar", list(linhas_do_menu()) == ["Restaurar a barra lateral"])
clique(js("menu"), esq, 120, linhas_do_menu()["Restaurar a barra lateral"])
ok("restaurar devolve a ordem, os nomes e os itens retirados", nomes("favoritos") == antes and nomes("locais") == locais)
shutil.rmtree(os.path.dirname(motor_do_arquivos.ARRUMACAO), ignore_errors=True)
shutil.rmtree(base, ignore_errors=True)
sys.stdout.flush()
# Sai direto: desmontar a tela aqui só produziria avisos sem importância.
os._exit(0)
