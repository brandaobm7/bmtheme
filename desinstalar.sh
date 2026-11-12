#!/usr/bin/env bash
# Remove o tema bmos e volta ao visual que existia antes da instalação.

set -uo pipefail

DADOS="${XDG_DATA_HOME:-$HOME/.local/share}"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
ESTADO="$DADOS/bmos-tema"
ORIGINAL="$ESTADO/original"

ARQUIVOS_CONFIG="kdeglobals kwinrc plasmarc plasmashellrc plasma-org.kde.plasma.desktop-appletsrc
ksplashrc kscreenlockerrc kcminputrc gtkrc gtkrc-2.0 gtk-3.0/settings.ini gtk-4.0/settings.ini
gtk-4.0/gtk.css gtk-4.0/gtk-dark.css gtk-4.0/assets gtk-4.0/windows-assets xsettingsd/xsettingsd.conf
mimeapps.list"

passo() { printf '\n==> %s\n' "$*"; }
quieto() { "$@" >/dev/null 2>&1 || true; }

if [ ! -d "$ORIGINAL" ]; then
  echo "O tema bmos não está instalado para este usuário." >&2
  exit 1
fi

valor() { sed -n "s/^$1=//p" "$ORIGINAL/estado" | head -n 1; }

# O Plasma grava a própria configuração ao fechar. Para a cópia original não ser
# sobrescrita, a área de trabalho para durante a troca dos arquivos.
passo "Voltando a configuração anterior"
quieto systemctl --user stop plasma-plasmashell.service

# O Alt+Espaço volta para a busca do Plasma: primeiro o widget do bmos solta o
# atalho, depois a busca do Plasma recebe de volta as teclas que tinha.
ATALHOS="org.kde.kglobalaccel /kglobalaccel org.kde.KGlobalAccel"
if [ -f "$ESTADO/widget-busca" ]; then
  # shellcheck disable=SC2086
  quieto qdbus $ATALHOS.unregister plasmashell "activate widget $(cat "$ESTADO/widget-busca")"
fi
if [ -f "$ORIGINAL/atalho-busca" ]; then
  # O arquivo guarda as teclas como vieram: "a(ai) 3 4 tecla 0 0 0 ...".
  teclas=$(sed 's/^a(ai) //' "$ORIGINAL/atalho-busca")
  # shellcheck disable=SC2086
  quieto busctl --user call $ATALHOS setForeignShortcutKeys "asa(ai)" 4 org.kde.krunner.desktop _launch KRunner KRunner $teclas
fi
for arquivo in $ARQUIVOS_CONFIG; do
  rm -rf "${CONFIG:?}/$arquivo"
  if [ -e "$ORIGINAL/config/$arquivo" ] || [ -L "$ORIGINAL/config/$arquivo" ]; then
    mkdir -p "$CONFIG/$(dirname "$arquivo")"
    cp -a "$ORIGINAL/config/$arquivo" "$CONFIG/$arquivo"
  fi
done
rm -rf "$CONFIG/bmos"

if [ -f "$ORIGINAL/flatpak-global" ]; then
  cp -a "$ORIGINAL/flatpak-global" "$DADOS/flatpak/overrides/global"
else
  rm -f "$DADOS/flatpak/overrides/global"
fi

passo "Aplicando o visual anterior"
# Zera a contagem de partidas, que o sistema limita a três por minuto. Sem isso,
# desinstalar logo depois de instalar deixaria a pessoa sem a área de trabalho.
quieto systemctl --user reset-failed plasma-plasmashell.service
quieto systemctl --user start plasma-plasmashell.service
tema_global="$(valor tema_global)"
[ -n "$tema_global" ] && quieto plasma-apply-lookandfeel -a "$tema_global"
papel="$(valor papel)"
[ -n "$papel" ] && quieto plasma-apply-wallpaperimage "${papel#file://}"
quieto qdbus org.kde.KWin /KWin org.kde.KWin.reconfigure
quieto dbus-send --session --type=signal /KGlobalSettings org.kde.KGlobalSettings.notifyChange int32:2 int32:0

# Os apps abertos ainda usam a fonte e os ícones do tema. Eles recebem o aviso
# acima e voltam ao visual anterior. Só depois os arquivos são apagados, senão
# o texto desses apps viraria quadradinhos.
sleep 5

passo "Removendo os arquivos do tema"
rm -rf "$DADOS/wallpapers/bmos" "$DADOS/wallpapers/bmos-bloqueio" "$DADOS/fonts/bmos" \
  "$DADOS/color-schemes/BmosClaro.colors" "$DADOS/color-schemes/BmosEscuro.colors" \
  "$DADOS/plasma/look-and-feel/org.bmos.claro" "$DADOS/plasma/look-and-feel/org.bmos.escuro" \
  "$DADOS/plasma/desktoptheme/bmos-claro" "$DADOS/plasma/desktoptheme/bmos-escuro" \
  "$DADOS"/plasma/plasmoids/org.bmos.* \
  "$DADOS/aurorae/themes/MacTahoe-Light" "$DADOS/aurorae/themes/MacTahoe-Dark" \
  "$DADOS/themes/MacTahoe-Light" "$DADOS/themes/MacTahoe-Dark" \
  "$HOME/.local/bin/bmos-tema" "$HOME/.local/bin/bmos-arquivos" "$HOME/.local/bin/bmos-ajustes" \
  "$DADOS/applications/org.bmos.arquivos.desktop" "$DADOS/applications/org.bmos.ajustes.desktop"
rm -rf "$DADOS"/icons/MacTahoe "$DADOS"/icons/MacTahoe-light "$DADOS"/icons/MacTahoe-dark
quieto fc-cache -f "$DADOS/fonts"

# Aqui ficam também os apps Arquivos e Ajustes e o ambiente Python com o PySide6.
rm -rf "$ESTADO"
quieto kbuildsycoca6

printf '\nTema bmos removido. Se algum app aberto continuar com o visual antigo, feche e abra de novo.\n'
