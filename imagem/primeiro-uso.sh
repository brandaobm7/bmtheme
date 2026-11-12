#!/bin/sh
# Roda no login de cada usuário, na imagem bmos. Instala o tema na pasta pessoal
# a partir de /usr/share/bmtheme, sem baixar nada: na primeira vez, sempre que a
# imagem trouxer qualquer mudança no tema, e uma vez para quem tinha instalado o
# tema por conta própria antes de trocar para a imagem.
TEMA="${BMTHEME:-/usr/share/bmtheme}"
ESTADO="${XDG_DATA_HOME:-$HOME/.local/share}/bmos-tema"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"

# O comando do Qt que conversa com o Plasma muda de nome conforme a versão do
# Fedora: qdbus6, qdbus-qt6 ou, nas mais antigas, qdbus.
QDBUS="$(command -v qdbus6 || command -v qdbus-qt6 || command -v qdbus || echo /bin/false)"
qdbus() { "$QDBUS" "$@"; }

# Só na área de trabalho do Plasma. No modo de jogo não há o que tematizar.
[ "${XDG_CURRENT_DESKTOP:-}" = "KDE" ] || exit 0
# Quem desinstalou o tema de propósito fica sem ele.
[ -f "$CONFIG/bmos/sem-tema" ] && exit 0
# A assinatura muda quando qualquer arquivo do tema muda na imagem (construir.sh).
# Em dia com ela e já usando os componentes do sistema: nada a fazer.
assinatura="$(cat "$TEMA/assinatura" 2>/dev/null || cat "$TEMA/VERSAO" 2>/dev/null)"
if [ "$assinatura" = "$(cat "$ESTADO/assinatura" 2>/dev/null)" ] && [ ! -d "$ESTADO/venv" ]; then
  exit 0
fi

# O instalador troca a barra e a dock: espera a área de trabalho terminar de subir.
for _ in $(seq 1 60); do
  qdbus org.kde.plasmashell /PlasmaShell >/dev/null 2>&1 && break
  sleep 1
done
sleep 3

modo="$(cat "$CONFIG/bmos/tema" 2>/dev/null)"
[ "$modo" = "escuro" ] || modo=claro
mkdir -p "$HOME/.local/state"
"$TEMA/instalar.sh" "$modo" >"$HOME/.local/state/bmtheme-instalacao.log" 2>&1 || exit 1
# Só depois de dar certo: se falhar, tenta de novo no próximo login.
printf '%s\n' "$assinatura" >"$ESTADO/assinatura"
