#!/bin/bash
. ~/ambiente
export QT_FORCE_STDERR_LOGGING=1
cd ~
echo "== fixados na dock"
grep -n "^launchers=" ~/.config/plasma-org.kde.plasma.desktop-appletsrc | cut -c1-400
echo "assinatura: imagem $(cat /usr/share/bmtheme/assinatura 2>/dev/null) | usuário $(cat ~/.local/share/bmos-tema/assinatura 2>/dev/null)"
echo "== nomes dos apps"
python3 ~/.local/share/plasma/plasmoids/org.bmos.apps/contents/code/apps.py | python3 -c "import json,sys; print(' | '.join(a['nome'] for a in json.load(sys.stdin)))"
echo "== segundo login: não deve reinstalar"
( time /usr/libexec/bmtheme-primeiro-uso ) 2>&1 | grep real
echo "== apps (teste simulado)"
xdg-user-dirs-update 2>/dev/null; ls ~ | tr "\n" " "; echo
cd /fonte
for t in "teste_arquivos.py arquivos" "teste_cliques.py arquivos" "teste_ajustes.py ajustes"; do
  set -- $t
  QT_QPA_PLATFORM=offscreen timeout 180 /usr/lib/bmtheme/venv/bin/python -u testes/$1 $2 >/saida/$1.log 2>&1
  echo "$1: saida $? | $(awk "{print \$1}" /saida/$1.log | sort | uniq -c | grep -E " (ok|FALHOU|Traceback)" | tr "\n" " ")"
done
cd ~
echo "== janelas"
setsid ~/.local/bin/bmos-ajustes >/saida/ajustes.log 2>&1 &
sleep 7; timeout 20 spectacle -b -n -f -o /saida/3-ajustes.png >/dev/null 2>&1; pkill -f bmos-ajustes.py
setsid ~/.local/bin/bmos-arquivos >/saida/arquivos.log 2>&1 &
sleep 7; timeout 20 spectacle -b -n -f -o /saida/4-arquivos.png >/dev/null 2>&1
echo "== menus e controles (Kvantum)"
echo "estilo: $(kreadconfig6 --file kdeglobals --group KDE --key widgetStyle) | $(grep theme ~/.config/Kvantum/kvantum.kvconfig 2>/dev/null) | temas: $(ls /usr/share/Kvantum | grep -c bmos)"
setsid kwrite >/dev/null 2>&1 &
sleep 6; timeout 20 spectacle -b -n -f -o /saida/4c-editor.png >/dev/null 2>&1; pkill -x kwrite
setsid systemsettings kcm_kscreen >/dev/null 2>&1 &
sleep 9; timeout 20 spectacle -b -n -f -o /saida/4d-configuracoes.png >/dev/null 2>&1; pkill -x systemsettings
echo "== tela de bloqueio (modo de teste, numa janela, sem travar nada)"
echo "tela de bloqueio: arquivos com conteúdo diferente do pacote do Plasma: $(rpm -V plasma-desktop 2>/dev/null | grep lockscreen | grep "^..5" | sed "s#.*/lockscreen/##" | tr "\n" " ")(deve ser só LockScreenUi.qml) | correção para conta sem senha: $(grep -c "imagem/bloqueio-sem-senha.py" /usr/share/plasma/shells/org.kde.plasma.desktop/contents/lockscreen/LockScreenUi.qml) de 1 | papel de parede: $(kreadconfig6 --file kscreenlockerrc --group Greeter --group Wallpaper --group org.kde.image --group General --key Image | sed "s#.*/wallpapers/##")"
setsid /usr/libexec/kscreenlocker_greet --testing >/saida/bloqueio.log 2>&1 &
sleep 7; timeout 20 spectacle -b -n -f -o /saida/4e-bloqueio.png >/dev/null 2>&1; pkill -f kscreenlocker_greet; sleep 1
echo "erros de QML na tela de bloqueio: $(grep -cE "TypeError|ReferenceError|is not a type|Cannot assign|Unable to assign|is not defined|SyntaxError|failed to load|Error loading" /saida/bloqueio.log)"
grep -E "TypeError|ReferenceError|is not a type|Cannot assign|Unable to assign|is not defined|SyntaxError|failed to load|Error loading" /saida/bloqueio.log | head -5 | cut -c1-200
echo "== tela de login (modo de teste)"
echo "papel de parede: $(grep -m1 "^Image=" /usr/lib/plasmalogin/defaults.conf) | ajustes: $(XDG_CONFIG_HOME=/tmp/vazio XDG_CONFIG_DIRS=/usr/lib/plasmalogin/bmos kreadconfig6 --file kdeglobals --group General --key ColorScheme), $(XDG_CONFIG_HOME=/tmp/vazio XDG_CONFIG_DIRS=/usr/lib/plasmalogin/bmos kreadconfig6 --file kdeglobals --group General --key font | cut -d, -f1) | serviços: $(ls /usr/lib/systemd/user/plasma-login.service.d/bmos.conf /usr/lib/systemd/user/plasma-wallpaper.service.d/bmos.conf 2>/dev/null | wc -l) de 2"
(
  export HOME=/tmp/casa-login XDG_CONFIG_HOME=/tmp/casa-login/.config XDG_CACHE_HOME=/tmp/casa-login/.cache
  export XDG_CONFIG_DIRS=/usr/lib/plasmalogin/bmos:/usr/share/kde-settings/kde-profile/default/xdg:/etc/xdg
  mkdir -p "$XDG_CONFIG_HOME"
  setsid /usr/bin/plasma-login-wallpaper >/saida/login-papel.log 2>&1 &
  sleep 5; timeout 20 spectacle -b -n -f -o /saida/4f-login-papel.png >/dev/null 2>&1
  setsid /usr/libexec/plasma-login-greeter --test >/saida/login.log 2>&1 &
  sleep 7; timeout 20 spectacle -b -n -f -o /saida/4g-login.png >/dev/null 2>&1
  pkill -f plasma-login-greeter; pkill -f plasma-login-wallpaper; sleep 1
)
echo "erros na tela de login: $(cat /saida/login.log /saida/login-papel.log | grep -cE "TypeError|ReferenceError|is not a type|SyntaxError|failed to load|Error loading|not a valid package")"
echo "== tela de boot"
echo "tema de boot: $(plymouth-set-default-theme 2>/dev/null) | peças: $(ls /usr/share/plymouth/themes/bmos/*.png 2>/dev/null | wc -l) de 6"
echo "== ajustes visuais"
echo "tecla Windows: widget que se declara lançador: $(grep -l "org.kde.plasma.launchermenu" ~/.local/share/plasma/plasmoids/*/metadata.json | xargs -n1 dirname | xargs -n1 basename | tr "\n" " ")| ajuste antigo do KWin: $(grep -c "^Meta=" ~/.config/kwinrc) (deve ser 0)"
busctl --user call org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell activateLauncherMenu >/dev/null 2>&1; sleep 2; timeout 20 spectacle -b -n -f -o /saida/4h-tecla-windows.png >/dev/null 2>&1
busctl --user call org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell activateLauncherMenu >/dev/null 2>&1; sleep 1
echo "apps em GTK4 (Loja de Apps): $(grep -c "gravado por bmos-tema" ~/.config/gtk-4.0/gtk.css) de 1 | importa: $(grep -o "themes/MacTahoe-[A-Za-z]*/gtk-4.0/gtk.css" ~/.config/gtk-4.0/gtk.css) | o arquivo importado existe: $(ls $(grep -o "file://[^\"]*" ~/.config/gtk-4.0/gtk.css | sed "s#file://##") 2>/dev/null | wc -l) de 1"
echo "sombra só na busca: $(cat ~/.local/share/plasma/desktoptheme/bmos-claro/dialogs/background.svg ~/.local/share/plasma/desktoptheme/bmos-escuro/dialogs/background.svg | grep -c 'id="shadow-') peças de sombra no estilo dos popups (deve ser 0) | janela da sombra: $(ls ~/.local/share/plasma/plasmoids/org.bmos.apps/contents/ui/SombraDaBusca.qml 2>/dev/null | wc -l) de 1"
for tema in Light Dark; do
  python3 - /usr/share/aurorae/themes/MacTahoe-$tema ~/.local/share/aurorae/themes/MacTahoe-$tema <<'PY'
import os, re, sys
pasta, pessoal = sys.argv[1:3]
svg = open(pasta + "/decoration.svg").read()
def cor(peca):
    achado = re.search(r'<path\b[^>]*\bid="%s"[^>]*>' % peca, svg, re.S)
    return re.search(r"fill:(#[0-9a-f]{6})", achado.group(0)).group(1)
print("barra de título %s: com foco %s, sem foco %s | %s | cópia pessoal: %s" % (
    os.path.basename(pasta), cor("decoration-center"), cor("decoration-inactive-center"),
    "tingida" if os.path.exists(pasta + "/.tingido-pelo-bmos") else "SEM TINGIR",
    "EXISTE" if os.path.exists(pessoal) else "não há"))
PY
done
echo "cantos das janelas: raio no tema $(grep -h "^BmosCornerRadius=" /usr/share/aurorae/themes/MacTahoe-Dark/*rc /usr/share/aurorae/themes/MacTahoe-Light/*rc | tr "\n" " ")| motor da decoração com a troca: $(for p in org.kde.kwin.aurorae.so org.kde.kwin.aurorae.v2.so; do grep -c BmosCornerRadius /usr/lib64/qt6/plugins/org.kde.kdecoration3/$p; done | grep -c "^[1-9]") de 2 | pacotes de compilação na imagem: $(rpm -qa "cmake" "extra-cmake-modules" "kdecoration-devel" "qt6-qtbase-devel" | wc -l) de 0"
echo "sombra das janelas: $(grep -o "stop-color:#[0-9a-f]*" /usr/share/aurorae/themes/MacTahoe-Dark/decoration.svg | sort | uniq -c | tr "\n" " ")(deve ser só #292159)"
echo "logo da abertura da sessão: $(readlink ~/.local/share/plasma/look-and-feel/org.bmos.claro/contents/splash/images/logo.svg)"
for tema in /usr/share/themes/MacTahoe-Dark ~/.local/share/themes/MacTahoe-Dark; do
  python3 - "$tema/gtk-3.0/gtk.css" <<'PY'
import re, sys
texto = open(sys.argv[1], encoding="utf-8", errors="replace").read()
cores = re.findall(r"#([0-9a-fA-F]{6})\b", texto)
neutros = [c for c in cores if c[0:2] == c[2:4] == c[4:6] and c.lower() not in ("000000", "ffffff")]
print(f"tema GTK {sys.argv[1]}: {len(cores)} cores, {len(neutros)} cinzas neutros")
PY
done
echo "Chrome no tema do sistema: $(cat ~/.var/app/com.google.Chrome/config/google-chrome/Default/Preferences 2>/dev/null)"
cp /usr/share/plymouth/themes/bmos/logo.png /saida/boot-logo.png 2>/dev/null
echo "== grade de apps pelo ícone da dock"
~/.local/bin/bmos-apps; sleep 2; timeout 20 spectacle -b -n -f -o /saida/4b-grade.png >/dev/null 2>&1
~/.local/bin/bmos-apps; sleep 1
echo "== limpeza da imagem"
ujust --list >/dev/null 2>&1 && echo "ujust: funciona" || echo "ujust: QUEBRADO"
grep -hE "^(application/pdf|text/plain|text/html)=" /usr/share/applications/kde-mimeapps.list /usr/share/applications/mimeapps.list | tr "\n" " "; echo
for app in waydroid lutris kate kdeconnect-app krfb input-remapper-gtk; do command -v $app >/dev/null && echo "AINDA EXISTE: $app"; done
echo "citam apps removidos, fora traduções e ícones: $(find /etc /usr/bin /usr/libexec /usr/lib/systemd /usr/share/applications /usr/share/ublue-os 2>/dev/null | grep -icE "waydroid|lutris|sunshine|input-remapper|kdeconnect|krfb|kwalletmanager|khelpcenter|webapp-manager")"
bmos-limpar-restos --ver
echo "== modo escuro"
( time ~/.local/bin/bmos-tema escuro ) 2>&1 | grep -E "real|rro"
sleep 6; timeout 20 spectacle -b -n -f -o /saida/5-escuro.png >/dev/null 2>&1; pkill -f bmos-arquivos.py
grep -c . /saida/ajustes.log /saida/arquivos.log; grep -vE "bluez|kf\.|qt\.qpa" /saida/ajustes.log /saida/arquivos.log | head -12 | cut -c1-220
ls -la /saida/*.png
