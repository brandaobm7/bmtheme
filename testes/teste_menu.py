"""Testa as ações do menu do Arquivos sem abrir janela, numa pasta temporária:
criar arquivo, mover para nova pasta, copiar localização, cor da pasta, abrir
pasta com, compactar e extrair pelo Ark.

As cores de pasta dependem do tema de ícones, que só é lido com a tela de
verdade: sem ela, essa verificação falha e isso é esperado.

Uso, com o tema instalado:
  ~/.local/share/bmos-tema/venv/bin/python -u testes/teste_menu.py arquivos
"""
import os, sys, tempfile, time, shutil
os.environ["QT_QPA_PLATFORM"] = "offscreen"
sys.path.insert(0, sys.argv[1])
from PySide6.QtGui import QGuiApplication
app = QGuiApplication(sys.argv)
from PySide6.QtGui import QIcon; QIcon.setThemeName("MacTahoe")  # sem tela, o tema de ícones não vem do sistema
from arquivos import Arquivos, icone_escolhido
a = Arquivos(); avisos = []; a.aviso.connect(avisos.append)
def esperar(seg):
    fim = time.time() + seg
    while time.time() < fim: app.processEvents(); time.sleep(0.02)
ok = lambda nome, cond: print(("ok   " if cond else "FALHA"), nome)
base = tempfile.mkdtemp(prefix="bmos-arq-", dir=os.path.expanduser("~"))
try:
    n1 = a.novoArquivo(base, "Novo arquivo.txt"); n2 = a.novoArquivo(base, "Novo arquivo.txt"); n3 = a.novoArquivo(base, "Novo arquivo")
    ok("novo arquivo de texto e vazio, sem repetir nome", sorted(os.listdir(base)) == ["Novo arquivo", "Novo arquivo 2.txt", "Novo arquivo.txt"]); print("    ", sorted(os.listdir(base)))
    a.copiarTexto(n1); esperar(0.2); ok("copiar localização", QGuiApplication.clipboard().text() == n1)
    p = a.moverParaNovaPasta([n1, n2]); ok("mover para nova pasta", os.path.isdir(p) and sorted(os.listdir(p)) == ["Novo arquivo 2.txt", "Novo arquivo.txt"])
    cores = a.coresDePasta(); print("     cores de pasta:", [c["nome"] for c in cores]); ok("cores de pasta do tema", len(cores) >= 5)
    if cores:
        a.corDaPasta(p, cores[0]["icone"]); ok("pintar pasta", icone_escolhido(p) == cores[0]["icone"])
        item = [i for i in a.listar(base, False) if i["caminho"] == p][0]; ok("a lista mostra a cor", item["icone"] == cores[0]["icone"])
        a.corDaPasta(p, ""); ok("voltar à cor padrão apaga a marca", not os.path.exists(os.path.join(p, ".directory")))
    ok("programas", a.temComando("ark") and a.temComando("filelight") and a.temComando("dolphin") and not a.temComando("nao-existe-xyz"))
    apps = a.appsPara(p); print("     abrir pasta com:", [(x["nome"], x["icone"]) for x in apps]); ok("abrir pasta com (sem o próprio Arquivos)", len(apps) >= 1 and all("bmos" not in x["id"] for x in apps))
    open(os.path.join(p, "Novo arquivo.txt"), "w").write("conteudo\n" * 50)
    a.compactar([p], "zip"); esperar(6); zips = [f for f in os.listdir(base) if f.endswith(".zip")]; ok("compactar em ZIP pelo Ark", len(zips) == 1); print("    ", zips)
    if zips:
        dest = os.path.join(base, "saida"); os.mkdir(dest); shutil.move(os.path.join(base, zips[0]), dest)
        a.extrair([os.path.join(dest, zips[0])], False); esperar(6); ok("extrair aqui pelo Ark", len(os.listdir(dest)) == 2); print("    ", sorted(os.listdir(dest)))
    print("     avisos:", avisos)
finally:
    shutil.rmtree(base, ignore_errors=True)
