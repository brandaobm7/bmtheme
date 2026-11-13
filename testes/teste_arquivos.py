"""Testa o motor do Arquivos (arquivos.py) sem abrir janela, numa pasta temporária:
listar, criar pasta, renomear, copiar, mover, duplicar, Lixeira e restaurar.

Uso, com o tema instalado:
  ~/.local/share/bmos-tema/venv/bin/python -u testes/teste_arquivos.py arquivos
"""
import os, sys, tempfile, time, shutil
os.environ["QT_QPA_PLATFORM"] = "offscreen"
sys.path.insert(0, sys.argv[1])
from PySide6.QtGui import QGuiApplication
from PySide6.QtCore import QTimer
app = QGuiApplication(sys.argv)
from arquivos import Arquivos
a = Arquivos()
avisos = []; a.aviso.connect(avisos.append)
def esperar(seg):
    fim = time.time() + seg
    while time.time() < fim:
        app.processEvents(); time.sleep(0.02)
base = tempfile.mkdtemp(prefix="bmos-arq-", dir=os.path.expanduser("~"))
ok = lambda nome, cond: print(("ok   " if cond else "FALHA"), nome)
try:
    open(os.path.join(base, "nota.txt"), "w").write("oi\n"); os.mkdir(os.path.join(base, "sub"))
    itens = a.listar(base, False); nomes = sorted(i["nome"] for i in itens)
    ok("listar", nomes == ["nota.txt", "sub"]); print("     item:", {k: itens[0][k] for k in list(itens[0])[:8]})
    info = a.info(base); ok("info", info.get("existe") and info.get("gravavel")); print("     livre:", info.get("livre"))
    ok("endereço da lixeira do sistema", a.resolver("trash:/") == "lixeira:")
    nova = a.novaPasta(base); ok("nova pasta", os.path.isdir(nova)); print("    ", os.path.basename(nova))
    ren = a.renomear(os.path.join(base, "nota.txt"), "carta.txt"); ok("renomear", os.path.isfile(os.path.join(base, "carta.txt")))
    a.copiar([os.path.join(base, "carta.txt")], False); esperar(0.3); ok("pode colar", a.podeColar)
    a.colar(os.path.join(base, "sub")); esperar(1.5); ok("colar (copiar)", os.path.isfile(os.path.join(base, "sub", "carta.txt")))
    a.colar(base); esperar(1.5); ok("colar no mesmo lugar não substitui", len([n for n in os.listdir(base) if n.startswith("carta")]) == 2); print("    ", sorted(os.listdir(base)))
    a.copiar([os.path.join(base, "sub", "carta.txt")], True); esperar(0.3); a.colar(nova); esperar(1.5)
    ok("recortar e colar (mover)", os.path.isfile(os.path.join(nova, "carta.txt")) and not os.path.exists(os.path.join(base, "sub", "carta.txt")))
    a.duplicar([os.path.join(base, "carta.txt")]); esperar(1.5); ok("duplicar", len([n for n in os.listdir(base) if n.startswith("carta")]) == 3)
    alvo = os.path.join(base, "carta.txt"); a.paraLixeira([alvo]); esperar(2); ok("para a lixeira", not os.path.exists(alvo))
    lix = a.listar("lixeira:", False); meu = [i for i in lix if i["nome"] == "carta.txt"]
    ok("aparece na lixeira", len(meu) >= 1)
    if meu:
        a.restaurar([meu[0]["caminho"]]); esperar(2); ok("restaurar", os.path.isfile(alvo))
    print("     locais:", [(l["nome"], l["caminho"]) for l in a.locais()])
    print("     favoritos:", [f["nome"] for f in a.favoritos()])
    apps = a.appsPara(alvo); print("     abrir com:", [x.get("nome") for x in apps][:5])
    p = a.previa(alvo); ok("pré-visualização de texto", p.get("classe") == "texto")
    print("     avisos:", avisos)
finally:
    shutil.rmtree(base, ignore_errors=True)
QTimer.singleShot(0, app.quit); app.exec()
