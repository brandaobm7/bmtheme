#!/usr/bin/env python3
"""Vitrine dos controles do Qt, para ver um tema do Kvantum sem precisar clicar.

Abre uma janela com os controles mais comuns e, sozinha, abre um menu com
submenu por cima. Uso: vitrine.py [claro|escuro]
"""
import sys
from PyQt6.QtCore import QPoint, Qt, QTimer
from PyQt6.QtGui import QAction, QIcon, QKeySequence
from PyQt6.QtWidgets import (QApplication, QCheckBox, QComboBox, QGridLayout, QGroupBox, QHBoxLayout, QLabel,
                             QLineEdit, QListWidget, QMainWindow, QMenu, QProgressBar, QPushButton, QRadioButton,
                             QSlider, QSpinBox, QTabWidget, QVBoxLayout, QWidget)

app = QApplication(sys.argv)
janela = QMainWindow()
janela.setWindowTitle("Vitrine")
centro = QWidget()
janela.setCentralWidget(centro)
grade = QGridLayout(centro)

abas = QTabWidget()
aba = QWidget()
coluna = QVBoxLayout(aba)
linha = QHBoxLayout()
for texto, padrao in (("Cancelar", False), ("Aplicar", False), ("OK", True)):
    botao = QPushButton(texto)
    botao.setDefault(padrao)
    linha.addWidget(botao)
desligado = QPushButton("Desligado")
desligado.setEnabled(False)
linha.addWidget(desligado)
coluna.addLayout(linha)
campo = QLineEdit("Campo de texto")
coluna.addWidget(campo)
lista = QComboBox()
lista.addItems(["Do anoitecer ao amanhecer", "Sempre ligada", "Desligada"])
coluna.addWidget(lista)
linha2 = QHBoxLayout()
marca = QCheckBox("Marcado")
marca.setChecked(True)
linha2.addWidget(marca)
linha2.addWidget(QCheckBox("Desmarcado"))
radio = QRadioButton("Escolhido")
radio.setChecked(True)
linha2.addWidget(radio)
linha2.addWidget(QRadioButton("Outro"))
linha2.addWidget(QSpinBox())
coluna.addLayout(linha2)
barra = QSlider(Qt.Orientation.Horizontal)
barra.setValue(45)
coluna.addWidget(barra)
progresso = QProgressBar()
progresso.setValue(60)
coluna.addWidget(progresso)
abas.addTab(aba, "Geral")
abas.addTab(QWidget(), "Avançado")
abas.addTab(QWidget(), "Sobre")
grade.addWidget(abas, 0, 0)

grupo = QGroupBox("Lista")
dentro = QVBoxLayout(grupo)
itens = QListWidget()
itens.addItems(["Documentos", "Downloads", "Imagens", "Músicas", "Vídeos", "Projetos"])
itens.setCurrentRow(2)
dentro.addWidget(itens)
dentro.addWidget(QLabel("Texto comum e <a href='#'>um link</a>"))
grade.addWidget(grupo, 0, 1)

barra_de_menus = janela.menuBar()
arquivo = barra_de_menus.addMenu("Arquivo")
arquivo.addAction("Novo")
barra_de_menus.addMenu("Editar")
barra_de_menus.addMenu("Exibir")

menu = QMenu(janela)
for nome, icone, atalho in (("Abrir", "document-open", "Return"), ("Abrir em nova janela", "window-new", "Ctrl+N")):
    acao = QAction(QIcon.fromTheme(icone), nome, menu)
    acao.setShortcut(QKeySequence(atalho))
    menu.addAction(acao)
menu.addSeparator()
sub = menu.addMenu(QIcon.fromTheme("view-sort"), "Ordenar por")
for nome in ("Nome", "Data de modificação", "Tamanho", "Tipo"):
    acao = sub.addAction(nome)
    acao.setCheckable(True)
    acao.setChecked(nome == "Nome")
copiar = QAction(QIcon.fromTheme("edit-copy"), "Copiar", menu)
copiar.setShortcut(QKeySequence("Ctrl+C"))
menu.addAction(copiar)
colar = QAction(QIcon.fromTheme("edit-paste"), "Colar", menu)
colar.setEnabled(False)
menu.addAction(colar)
oculto = menu.addAction("Mostrar arquivos ocultos")
oculto.setCheckable(True)
oculto.setChecked(True)
menu.addSeparator()
menu.addAction(QIcon.fromTheme("document-properties"), "Propriedades")

janela.resize(980, 520)
janela.show()


def abrir_menu():
    menu.popup(janela.mapToGlobal(QPoint(560, 250)))
    menu.setActiveAction(copiar)


def abrir_sub():
    menu.setActiveAction(sub.menuAction())
    sub.popup(menu.mapToGlobal(QPoint(menu.width() - 4, menu.actionGeometry(sub.menuAction()).top())))
    sub.setActiveAction(sub.actions()[1])


def fotografar():
    """Desenha o menu e o submenu direto em arquivos, sem depender de eles abrirem na tela."""
    pasta = next((a.split("=")[1] for a in sys.argv if a.startswith("--foto=")), "")
    for nome, peca, ativa in (("menu", menu, sub.menuAction()), ("submenu", sub, sub.actions()[1])):
        peca.ensurePolished()
        peca.adjustSize()
        peca.setActiveAction(ativa)
        peca.grab().save(f"{pasta}/{nome}.png")
    menu.setActiveAction(copiar)
    menu.grab().save(f"{pasta}/menu2.png")
    janela.grab().save(f"{pasta}/janela.png")


if any(a.startswith("--foto=") for a in sys.argv):
    QTimer.singleShot(1500, fotografar)
else:
    QTimer.singleShot(1500, abrir_menu)
    if "--sub" in sys.argv:
        QTimer.singleShot(2300, abrir_sub)
QTimer.singleShot(int(next((a.split("=")[1] for a in sys.argv if a.startswith("--tempo=")), "9000")), app.quit)
sys.exit(app.exec())
