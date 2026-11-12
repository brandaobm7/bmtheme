#!/bin/bash
# Fotografa a vitrine de controles com um tema do Kvantum, dentro da sessão de
# teste da imagem (ver testes/sessao-na-imagem). Serve para ajustar o desenho dos
# menus sem depender de cliques.
#
# Uso, dentro do contêiner, como o usuário de teste e com a sessão no ar:
#   ver.sh PASTA_DO_TEMA NOME SAIDA [claro|escuro]
# O contêiner precisa do Kvantum (a imagem bmos traz) e do PyQt6, que não vem:
#   dnf5 -y install python3-pyqt6
# A pasta desta vitrine entra montada em /kv, e as fotos saem em /saida.
. ~/ambiente
pasta="$1"; nome="$2"; saida="$3"; modo="${4:-claro}"
~/.local/bin/bmos-tema "$modo" >/dev/null 2>&1
mkdir -p ~/.config/Kvantum /saida/"$saida"
rm -rf ~/.config/Kvantum/"$nome"
cp -r "$pasta" ~/.config/Kvantum/"$nome"
printf '[General]\ntheme=%s\n' "$nome" >~/.config/Kvantum/kvantum.kvconfig
QT_STYLE_OVERRIDE=kvantum timeout 20 python3 /kv/vitrine.py --foto=/saida/"$saida" --tempo=3500 2>&1 | grep -viE "bluez|^$" | head -5
cd /saida/"$saida" || exit 1
fundo="#e9e6f5"; [ "$modo" = escuro ] && fundo="#3a3560"
# O menu (com dois realces) e o submenu lado a lado sobre um fundo liso, e a janela embaixo.
magick menu.png menu2.png submenu.png +repage -background "$fundo" -gravity north +append +repage \
  -bordercolor "$fundo" -border 14 -background "$fundo" -flatten menus.png
magick menus.png janela.png -background "$fundo" -gravity west -append -quality 90 /saida/v-"$saida".jpg
magick menus.png -quality 92 /saida/m-"$saida".jpg
