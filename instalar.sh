#!/usr/bin/env bash
# Instala o tema bmos no KDE Plasma 6, na pasta pessoal do usuário.
# Não pede senha e não altera o sistema. Para desfazer: ./desinstalar.sh
#
# Uso: ./instalar.sh [claro|escuro]
#
# Na imagem bmos, os componentes de terceiros (fonte, ícones, decoração, tema GTK
# e PySide6) já vêm no sistema. Este instalador percebe e não baixa de novo.
# Quem os põe lá é a construção da imagem, com:
#      ./instalar.sh --componentes-do-sistema

set -euo pipefail

AQUI="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=versoes.conf
. "$AQUI/versoes.conf"

SO_COMPONENTES=""
if [ "${1:-}" = "--componentes-do-sistema" ]; then
  SO_COMPONENTES=1
  shift
fi

MODO="${1:-claro}"
case "$MODO" in
  claro | escuro) ;;
  *) echo "Uso: ./instalar.sh [claro|escuro]" >&2 && exit 2 ;;
esac

DADOS="${XDG_DATA_HOME:-$HOME/.local/share}"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
ESTADO="$DADOS/bmos-tema"
ORIGINAL="$ESTADO/original"
TEMP="$(mktemp -d)"
trap 'rm -rf "$TEMP"' EXIT

# Onde a imagem bmos guarda os componentes de terceiros.
SISTEMA=/usr/share
AMBIENTE_DO_SISTEMA=/usr/lib/bmtheme/venv
if [ -n "$SO_COMPONENTES" ]; then
  DADOS="$SISTEMA"
  ESTADO="$TEMP/estado"
fi
# do_sistema CAMINHO: diz se a imagem já trouxe este componente.
do_sistema() { [ -z "$SO_COMPONENTES" ] && [ -e "$SISTEMA/$1" ]; }

# O comando do Qt que conversa com o Plasma muda de nome conforme a versão do
# Fedora: qdbus6, qdbus-qt6 ou, nas mais antigas, qdbus.
QDBUS="$(command -v qdbus6 || command -v qdbus-qt6 || command -v qdbus || echo /bin/false)"
qdbus() { "$QDBUS" "$@"; }

# Arquivos de configuração que o tema altera, guardados antes da primeira instalação.
ARQUIVOS_CONFIG="kdeglobals kwinrc plasmarc plasmashellrc plasma-org.kde.plasma.desktop-appletsrc
ksplashrc kscreenlockerrc kcminputrc gtkrc gtkrc-2.0 gtk-3.0/settings.ini gtk-4.0/settings.ini
gtk-4.0/gtk.css gtk-4.0/gtk-dark.css gtk-4.0/assets gtk-4.0/windows-assets xsettingsd/xsettingsd.conf
mimeapps.list"

passo() { printf '\n==> %s\n' "$*"; }
erro() { printf 'Erro: %s\n' "$*" >&2 && exit 1; }

if [ -z "$SO_COMPONENTES" ]; then
  [ "$(id -u)" -ne 0 ] || erro "rode como o seu usuário, sem sudo."
  command -v plasmashell >/dev/null || erro "este tema é para o KDE Plasma."
  command -v kwriteconfig6 >/dev/null || erro "este tema precisa do Plasma 6."
  [ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ] || erro "rode dentro da sessão do Plasma, em um terminal do próprio desktop."
  [ "$QDBUS" != /bin/false ] || erro "falta o comando qdbus do Qt 6 (pacote qt6-qttools)."
fi
for comando in curl git unzip tar; do
  command -v "$comando" >/dev/null || erro "falta o comando $comando."
done

conferir() {
  echo "$2  $1" | sha256sum -c --quiet - || erro "o arquivo baixado não confere: $(basename "$1")"
}

# baixar_repositorio NOME ENDERECO COMMIT: deixa o repositório em $TEMP/NOME, na versão fixa.
baixar_repositorio() {
  mkdir -p "$TEMP/$1"
  git -C "$TEMP/$1" init -q
  git -C "$TEMP/$1" fetch -q --depth 1 "$2" "$3"
  git -C "$TEMP/$1" -c advice.detachedHead=false checkout -q FETCH_HEAD
}

versao_instalada() { cat "$ESTADO/$1.versao" 2>/dev/null || true; }
marcar_versao() { echo "$2" >"$ESTADO/$1.versao"; }

# ------------------------------------------------------------------ cópia do original
mkdir -p "$ESTADO"
# Daqui até os componentes de terceiros é tudo do usuário: não entra na construção da imagem.
if [ -z "$SO_COMPONENTES" ]; then
if [ ! -d "$ORIGINAL" ]; then
  passo "Guardando a configuração atual"
  mkdir -p "$ORIGINAL/config"
  for arquivo in $ARQUIVOS_CONFIG; do
    if [ -e "$CONFIG/$arquivo" ] || [ -L "$CONFIG/$arquivo" ]; then
      mkdir -p "$ORIGINAL/config/$(dirname "$arquivo")"
      cp -a "$CONFIG/$arquivo" "$ORIGINAL/config/$arquivo"
    fi
  done
  {
    echo "tema_global=$(kreadconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage)"
    echo "papel=$(sed -n 's/^Image=//p' "$CONFIG/plasma-org.kde.plasma.desktop-appletsrc" 2>/dev/null | head -n 1)"
  } >"$ORIGINAL/estado"
  if [ -f "$DADOS/flatpak/overrides/global" ]; then
    cp -a "$DADOS/flatpak/overrides/global" "$ORIGINAL/flatpak-global"
  fi
fi

# ------------------------------------------------------------------ arquivos do bmos
passo "Papel de parede, cores e tema global"
rm -rf "$DADOS/wallpapers/bmos" "$DADOS/wallpapers/bmos-bloqueio"
mkdir -p "$DADOS/wallpapers" "$DADOS/color-schemes" "$DADOS/plasma/look-and-feel" "$HOME/.local/bin"
cp -r "$AQUI/papel-de-parede/bmos" "$DADOS/wallpapers/bmos"
# O mesmo papel de parede, mais escuro, para a tela de bloqueio.
cp -r "$AQUI/papel-de-parede/bmos-bloqueio" "$DADOS/wallpapers/bmos-bloqueio"
cp "$AQUI"/cores/*.colors "$DADOS/color-schemes/"
for pacote in "$AQUI"/tema-global/org.bmos.*; do
  destino="$DADOS/plasma/look-and-feel/$(basename "$pacote")"
  rm -rf "$destino"
  cp -r "$pacote" "$destino"
  # A tela de abertura é a mesma nos dois temas. Só o fundo muda: um atalho
  # para o papel de parede claro ou escuro, sem guardar a imagem duas vezes.
  cp -r "$AQUI/tema-global/comum/splash" "$destino/contents/splash"
  case "$(basename "$pacote")" in
    *escuro) fundo="images_dark" ;;
    *) fundo="images" ;;
  esac
  ln -sfn "$DADOS/wallpapers/bmos/contents/$fundo/3840x2400.png" "$destino/contents/splash/images/fundo.png"
done
install -m 755 "$AQUI/bin/bmos-tema" "$HOME/.local/bin/bmos-tema"
# Ícone "Apps" da dock: abre a grade de todos os apps. Fica fora da própria grade.
install -m 755 "$AQUI/bin/bmos-apps" "$HOME/.local/bin/bmos-apps"
ICONE_DOS_APPS="$ESTADO/apps.svg"
install -m 644 "$AQUI/paineis/apps.svg" "$ICONE_DOS_APPS"
mkdir -p "$DADOS/applications"
cat >"$DADOS/applications/org.bmos.grade.desktop" <<FIM
[Desktop Entry]
Type=Application
Name=Apps
Comment=Todos os apps
Exec=$HOME/.local/bin/bmos-apps
Icon=$ICONE_DOS_APPS
Terminal=false
NoDisplay=true
StartupNotify=false
FIM

passo "Estilo dos painéis e widgets da barra"
mkdir -p "$DADOS/plasma/desktoptheme" "$DADOS/plasma/plasmoids"
for estilo in "$AQUI"/estilo-plasma/*; do
  rm -rf "$DADOS/plasma/desktoptheme/$(basename "$estilo")"
  cp -r "$estilo" "$DADOS/plasma/desktoptheme/"
done
for widget in "$AQUI"/widgets/org.bmos.*; do
  destino="$DADOS/plasma/plasmoids/$(basename "$widget")"
  rm -rf "$destino"
  cp -r "$widget" "$destino"
  # As peças em comum e os ícones vão dentro de cada widget, que é um pacote fechado.
  cp "$AQUI"/widgets/comum/*.qml "$destino/contents/ui/"
  cp -r "$AQUI/icones-tabler" "$destino/contents/icons"
done
fi

# ------------------------------------------------------------------ fonte Inter
if ! do_sistema fonts/bmos/Inter-Regular.ttf \
   && { [ "$(versao_instalada inter)" != "$INTER_VERSAO" ] || [ ! -f "$DADOS/fonts/bmos/Inter-Regular.ttf" ]; }; then
  passo "Fonte Inter"
  curl -fsSL -o "$TEMP/inter.zip" "https://github.com/rsms/inter/releases/download/v$INTER_VERSAO/Inter-$INTER_VERSAO.zip"
  conferir "$TEMP/inter.zip" "$INTER_SHA256"
  # As versões estáticas têm o nome de família "Inter". A variável se chama
  # "Inter Variable", e os apps que pedem "Inter" não a encontrariam.
  rm -rf "$DADOS/fonts/bmos"
  mkdir -p "$DADOS/fonts/bmos"
  for peso in Regular Italic Medium MediumItalic SemiBold SemiBoldItalic Bold BoldItalic; do
    unzip -q -o -j "$TEMP/inter.zip" "extras/ttf/Inter-$peso.ttf" -d "$DADOS/fonts/bmos"
  done
  unzip -q -o -j "$TEMP/inter.zip" LICENSE.txt -d "$DADOS/fonts/bmos"
  fc-cache -f "$DADOS/fonts" >/dev/null 2>&1 || true
  marcar_versao inter "$INTER_VERSAO"
fi

# ------------------------------------------------------------------ ícones
if ! do_sistema icons/MacTahoe && [ "$(versao_instalada icones)" != "$MACTAHOE_ICONES" ]; then
  passo "Ícones MacTahoe (pode levar alguns minutos)"
  baixar_repositorio icones https://github.com/vinceliuice/MacTahoe-icon-theme.git "$MACTAHOE_ICONES"
  (cd "$TEMP/icones" && TERM="${TERM:-xterm}" ./install.sh -d "$DADOS/icons" </dev/null >/dev/null)
  marcar_versao icones "$MACTAHOE_ICONES"
fi

# ------------------------------------------------------------------ decoração das janelas
if ! do_sistema aurorae/themes/MacTahoe-Light && [ "$(versao_instalada decoracao)" != "$MACTAHOE_KDE" ]; then
  passo "Decoração das janelas"
  baixar_repositorio kde https://github.com/vinceliuice/MacTahoe-kde.git "$MACTAHOE_KDE"
  for variante in Light Dark; do
    destino="$DADOS/aurorae/themes/MacTahoe-$variante"
    rm -rf "$destino"
    mkdir -p "$destino"
    cp "$TEMP/kde/aurorae/MacTahoe-$variante"/*.svg "$TEMP/kde/aurorae/icons-$variante"/*.svg "$destino/"
    cp "$TEMP/kde/aurorae/${variante}rc" "$destino/MacTahoe-${variante}rc"
    cp "$TEMP/kde/aurorae/metadata.desktop" "$TEMP/kde/aurorae/metadata.json" "$destino/"
    sed -i "s/theme_name/MacTahoe-$variante/g" "$destino/metadata.desktop" "$destino/metadata.json"
  done
  marcar_versao decoracao "$MACTAHOE_KDE"
fi

# ------------------------------------------------------------------ apps GTK
if do_sistema themes/MacTahoe-Light; then
  # Na imagem o tema GTK já está no sistema. Os apps em Flatpak só enxergam a
  # pasta pessoal, então ele é copiado para lá, sem baixar nada.
  if [ "$(versao_instalada gtk)" != "$MACTAHOE_GTK" ] || [ ! -d "$DADOS/themes/MacTahoe-Light" ]; then
    passo "Tema dos apps GTK"
    mkdir -p "$DADOS/themes"
    for variante in Light Dark; do
      rm -rf "$DADOS/themes/MacTahoe-$variante"
      cp -r "$SISTEMA/themes/MacTahoe-$variante" "$DADOS/themes/"
    done
    marcar_versao gtk "$MACTAHOE_GTK"
  fi
elif [ "$(versao_instalada gtk)" != "$MACTAHOE_GTK" ]; then
  passo "Tema dos apps GTK"
  mkdir -p "$DADOS/themes"
  for variante in Light Dark; do
    soma="MACTAHOE_GTK_${variante^^}_SHA256"
    curl -fsSL -o "$TEMP/gtk-$variante.tar.xz" \
      "https://raw.githubusercontent.com/vinceliuice/MacTahoe-gtk-theme/$MACTAHOE_GTK/release/MacTahoe-$variante.tar.xz"
    conferir "$TEMP/gtk-$variante.tar.xz" "${!soma}"
    rm -rf "$DADOS/themes/MacTahoe-$variante"
    tar -xJf "$TEMP/gtk-$variante.tar.xz" -C "$DADOS/themes"
  done
  marcar_versao gtk "$MACTAHOE_GTK"
fi

# Os apps em Flatpak só enxergam o tema se tiverem acesso às pastas dele.
if [ -z "$SO_COMPONENTES" ] && command -v flatpak >/dev/null; then
  flatpak override --user --filesystem=xdg-data/themes:ro --filesystem=xdg-data/icons:ro \
    --filesystem=xdg-config/gtk-3.0:ro --filesystem=xdg-config/gtk-4.0:ro >/dev/null 2>&1 || true
fi

# ------------------------------------------------------------------ Arquivos e Ajustes
# Os dois apps do bmos são feitos em Python com PySide6, que o Bazzite não traz.
# O PySide6 vai para um ambiente Python só do tema, na pasta pessoal, sem tocar
# no sistema. Se o download falhar, o resto do tema é instalado e o Dolphin
# continua sendo o app de pastas.
AMBIENTE="$ESTADO/venv"
[ -z "$SO_COMPONENTES" ] || AMBIENTE="$AMBIENTE_DO_SISTEMA"
REQUISITOS="$(sha256sum "$AQUI/app-comum/requisitos.txt" | cut -d' ' -f1)"
arquivos_pronto=1
if [ -z "$SO_COMPONENTES" ] && [ -x "$AMBIENTE_DO_SISTEMA/bin/python" ]; then
  # Na imagem o PySide6 já está no sistema.
  AMBIENTE="$AMBIENTE_DO_SISTEMA"
  rm -rf "$ESTADO/venv" "$ESTADO/pyside.versao"
elif [ "$(versao_instalada pyside)" != "$REQUISITOS" ] || ! "$AMBIENTE/bin/python" -c "import PySide6" 2>/dev/null; then
  # A segunda condição pega o ambiente que parou de funcionar: quando o sistema
  # troca a versão do Python numa atualização, o ambiente antigo não abre mais.
  passo "Arquivos e Ajustes: baixando o PySide6 (cerca de 85 MB)"
  rm -rf "$AMBIENTE" "$ESTADO/pyside.versao"
  mkdir -p "$(dirname "$AMBIENTE")"
  if python3 -m venv "$AMBIENTE" \
     && "$AMBIENTE/bin/pip" install --quiet --disable-pip-version-check --require-hashes \
          --only-binary=:all: -r "$AQUI/app-comum/requisitos.txt"; then
    echo "$REQUISITOS" >"$ESTADO/pyside.versao"
  else
    arquivos_pronto=0
    rm -rf "$AMBIENTE"
    echo "Não foi possível baixar o PySide6. Os apps Arquivos e Ajustes não foram instalados: continuam o Dolphin e as Configurações do Sistema." >&2
  fi
fi
if [ -n "$SO_COMPONENTES" ]; then
  # Construção da imagem: os componentes estão no sistema, e o resto é de cada usuário.
  [ "$arquivos_pronto" = 1 ] || erro "o PySide6 não foi instalado."
  printf '\nComponentes de terceiros instalados no sistema.\n'
  exit 0
fi
# A desinstalação numa imagem bmos deixa um aviso para o tema não voltar sozinho
# no próximo login. Instalar de novo tira o aviso.
rm -f "$CONFIG/bmos/sem-tema"
if [ "$arquivos_pronto" = 1 ]; then
  passo "Arquivos e Ajustes"
  rm -rf "$ESTADO/arquivos" "$ESTADO/ajustes" "$ESTADO/app-comum"
  cp -r "$AQUI/arquivos" "$AQUI/ajustes" "$AQUI/app-comum" "$ESTADO/"
  mkdir -p "$HOME/.local/bin" "$DADOS/applications"
  cat >"$HOME/.local/bin/bmos-arquivos" <<FIM
#!/bin/sh
# Abre o app Arquivos do bmos com o Python do ambiente do tema.
exec "$AMBIENTE/bin/python" "$ESTADO/arquivos/bmos-arquivos.py" "\$@"
FIM
  cat >"$HOME/.local/bin/bmos-ajustes" <<FIM
#!/bin/sh
# Abre o app Ajustes do bmos com o Python do ambiente do tema.
exec "$AMBIENTE/bin/python" "$ESTADO/ajustes/bmos-ajustes.py" "\$@"
FIM
  chmod 755 "$HOME/.local/bin/bmos-arquivos" "$HOME/.local/bin/bmos-ajustes"
  cat >"$DADOS/applications/org.bmos.ajustes.desktop" <<FIM
[Desktop Entry]
Type=Application
Name=Ajustes
GenericName=Ajustes do sistema
Comment=Os ajustes do dia a dia, no visual do bmos
Exec=$HOME/.local/bin/bmos-ajustes
Icon=preferences-system
Terminal=false
Categories=Settings;
StartupWMClass=org.bmos.ajustes
StartupNotify=true
FIM
  cat >"$DADOS/applications/org.bmos.arquivos.desktop" <<FIM
[Desktop Entry]
Type=Application
Name=Arquivos
GenericName=Gerenciador de arquivos
Comment=Pastas e arquivos no estilo do bmos
Exec=$HOME/.local/bin/bmos-arquivos %u
Icon=system-file-manager
Terminal=false
Categories=System;FileTools;FileManager;
MimeType=inode/directory;
StartupWMClass=org.bmos.arquivos
StartupNotify=true
FIM
  # Pastas abrem no Arquivos. O Dolphin fica de reserva, se o Arquivos sair.
  kwriteconfig6 --file mimeapps.list --group "Default Applications" --key inode/directory \
    "org.bmos.arquivos.desktop;org.kde.dolphin.desktop;"
  kbuildsycoca6 >/dev/null 2>&1 || true
fi

# ------------------------------------------------------------------ aplicar
passo "Aplicando o tema"
FONTE="Inter,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
kwriteconfig6 --file kdeglobals --group General --key font "$FONTE"
kwriteconfig6 --file kdeglobals --group General --key menuFont "$FONTE"
kwriteconfig6 --file kdeglobals --group General --key toolBarFont "$FONTE"
kwriteconfig6 --file kdeglobals --group General --key smallestReadableFont "Inter,8,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
kwriteconfig6 --file kdeglobals --group WM --key activeFont "Inter,10,-1,5,600,0,0,0,0,0,0,0,0,0,0,1"

"$HOME/.local/bin/bmos-tema" "$MODO"

# A área de trabalho reinicia para enxergar os widgets novos ou atualizados.
reiniciar_area_de_trabalho() {
  # O sistema aceita só três partidas da área de trabalho por minuto e, passando
  # disso, não a inicia mais. Zerar a contagem antes evita que uma reinstalação
  # logo em seguida deixe a pessoa sem barra e sem dock.
  systemctl --user reset-failed plasma-plasmashell.service 2>/dev/null || true
  systemctl --user restart plasma-plasmashell.service 2>/dev/null || true
  for _ in $(seq 1 30); do
    qdbus org.kde.plasmashell /PlasmaShell >/dev/null 2>&1 && break
    sleep 1
  done
  sleep 2
}

# A barra e a dock são montadas só na primeira instalação, para não desfazer
# o que a pessoa arrumar depois.
if [ ! -f "$ESTADO/paineis" ]; then
  passo "Montando a barra superior e a dock"
  reiniciar_area_de_trabalho
  # A dock nasce com os apps que estavam fixados na barra de tarefas. Os que não
  # existem neste computador ficam de fora, para não virar um ícone vazio, e
  # também os que estão escondidos do menu de apps.
  ausentes=""
  fixados="$(qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$(cat "$AQUI/paineis/fixados.js")" 2>/dev/null || true)"
  for app in $(printf '%s' "$fixados" | tr ',' '\n' | sed -n 's/^applications://p' | sort -u); do
    achado=""
    for pasta in "$DADOS" $(printf '%s' "${XDG_DATA_DIRS:-}" | tr ':' ' ') /usr/local/share /usr/share \
                 /var/lib/flatpak/exports/share "$DADOS/flatpak/exports/share"; do
      # Um app numa subpasta tem o nome da subpasta na frente: kde-app.desktop é kde/app.desktop.
      for arquivo in "$pasta/applications/$app" "$pasta/applications/${app/-//}"; do
        if [ -e "$arquivo" ]; then
          grep -q '^NoDisplay=true' "$arquivo" || achado=1
          break 2
        fi
      done
    done
    [ -n "$achado" ] || ausentes="$ausentes\"$app\","
  done
  # O roteiro devolve o número da barra superior.
  if barra=$(qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "var ausentes = [${ausentes%,}];
$(cat "$AQUI/paineis/montar.js")" 2>/dev/null) \
     && [ -n "$barra" ] && [ "$barra" -gt 0 ] 2>/dev/null; then
    date +%s >"$ESTADO/paineis"
    : >"$ESTADO/apps-na-dock"
    # Popups da barra soltos dela, com os quatro cantos redondos. O roteiro dos painéis
    # não alcança esse ajuste: ele fica no arquivo de configuração e vale ao reiniciar.
    kwriteconfig6 --file plasmashellrc --group PlasmaViews --group "Panel $barra" --key floatingApplets 1
    reiniciar_area_de_trabalho
  else
    echo "Não foi possível montar os painéis. O restante do tema foi aplicado." >&2
  fi
else
  passo "Recarregando a barra e a dock"
  reiniciar_area_de_trabalho
  # Quem instalou antes de existir o ícone "Apps" ganha o ícone na dock, uma vez só:
  # se a pessoa tirar depois, ele não volta.
  if [ ! -f "$ESTADO/apps-na-dock" ]; then
    qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$(cat "$AQUI/paineis/apps-na-dock.js")" >/dev/null 2>&1 \
      && : >"$ESTADO/apps-na-dock"
  fi
fi

# ------------------------------------------------------------------ busca no Alt+Espaço
passo "Busca no Alt+Espaço"
ATALHOS="org.kde.kglobalaccel /kglobalaccel org.kde.KGlobalAccel"
BUSCA_DO_PLASMA="4 org.kde.krunner.desktop _launch KRunner KRunner"
ALT_ESPACO=134217760
# A busca do Plasma solta o Alt+Espaço e continua no Alt+F2. As teclas vêm no
# formato "a(ai) 3 4 tecla 0 0 0 4 tecla 0 0 0 ...": a quantidade e, para cada
# atalho, quatro números.
# shellcheck disable=SC2086
if teclas=$(busctl --user call $ATALHOS shortcutKeys as $BUSCA_DO_PLASMA 2>/dev/null); then
  [ -f "$ESTADO/original/atalho-busca" ] || echo "$teclas" >"$ESTADO/original/atalho-busca"
  sem_alt_espaco=$(echo "$teclas" | awk -v fora="$ALT_ESPACO" '{
    n = 0; s = ""
    for (i = 3; i + 4 <= NF; i += 5)
      if ($(i + 1) != fora) { n++; s = s " " $i " " $(i + 1) " " $(i + 2) " " $(i + 3) " " $(i + 4) }
    print n s }')
  # shellcheck disable=SC2086
  busctl --user call $ATALHOS setForeignShortcutKeys "asa(ai)" $BUSCA_DO_PLASMA $sem_alt_espaco >/dev/null 2>&1 || true
fi
por_atalho() {
  qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$(cat "$AQUI/paineis/atalhos.js")" 2>/dev/null
}
widget=$(por_atalho) || widget=""
anterior=$(cat "$ESTADO/widget-busca" 2>/dev/null || true)
if [ -n "$anterior" ] && [ "$anterior" != "$widget" ]; then
  # O widget de uma instalação anterior ainda segura o atalho. Solta e registra de novo.
  qdbus $ATALHOS.unregister plasmashell "activate widget $anterior" >/dev/null 2>&1 || true
  widget=$(por_atalho) || widget=""
fi
if [ -n "$widget" ]; then
  echo "$widget" >"$ESTADO/widget-busca"
else
  echo "Não foi possível pôr a busca no Alt+Espaço. Ela continua sendo a do Plasma." >&2
fi

cat "$AQUI/VERSAO" >"$ESTADO/instalado" 2>/dev/null || date +%Y.%m.%d >"$ESTADO/instalado"

printf '\nTema bmos instalado no modo %s.\n' "$MODO"
printf 'Trocar de modo: bmos-tema claro | bmos-tema escuro\n'
# Uma janela aberta continua com os arquivos da versão anterior na memória.
if pgrep -f "bmos-tema/(arquivos|ajustes)/bmos-" >/dev/null 2>&1; then
  printf 'O Arquivos ou o Ajustes está aberto: feche e abra de novo para usar a versão instalada agora.\n'
fi
printf 'Voltar ao visual anterior: %s/desinstalar.sh\n' "$AQUI"
