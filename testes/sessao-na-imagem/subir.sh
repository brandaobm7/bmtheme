#!/bin/bash
# Sobe o barramento, o gerenciador de janelas e a área de trabalho, e fica no ar.
cd ~
export XDG_RUNTIME_DIR=/tmp/run-teste
mkdir -p -m 700 "$XDG_RUNTIME_DIR" ~/bin
cat > ~/ambiente <<FIM
export XDG_RUNTIME_DIR=/tmp/run-teste
export XDG_CURRENT_DESKTOP=KDE KDE_FULL_SESSION=true KDE_SESSION_VERSION=6 XDG_SESSION_TYPE=wayland
export QT_QPA_PLATFORM=wayland KWIN_WAYLAND_NO_PERMISSION_CHECKS=1
export __EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/50_mesa.json
export XDG_CONFIG_DIRS=/usr/share/kde-settings/kde-profile/default/xdg:/etc/xdg
export PATH=\$HOME/bin:\$PATH LANG=pt_BR.UTF-8
export WAYLAND_DISPLAY=wayland-teste
FIM
. ~/ambiente
cat > ~/bin/systemctl <<"FIM"
#!/bin/bash
case "$*" in
  *"stop plasma-plasmashell.service"*) pkill -x plasmashell; sleep 2 ;;
  *"start plasma-plasmashell.service"*|*"restart plasma-plasmashell.service"*)
    pkill -x plasmashell; sleep 1
    setsid plasmashell >>/saida/plasmashell.log 2>&1 &
    ;;
esac
exit 0
FIM
chmod +x ~/bin/systemctl
dbus-daemon --session --fork --print-address > ~/barramento
echo "export DBUS_SESSION_BUS_ADDRESS=$(cat ~/barramento)" >> ~/ambiente
. ~/ambiente
unset WAYLAND_DISPLAY
setsid kwin_wayland --virtual --width 1920 --height 1080 --no-lockscreen --socket wayland-teste >/saida/kwin.log 2>&1 &
for _ in $(seq 1 30); do [ -S "$XDG_RUNTIME_DIR/wayland-teste" ] && break; sleep 1; done
export WAYLAND_DISPLAY=wayland-teste
sleep 3
setsid plasmashell >/saida/plasmashell.log 2>&1 &
sleep 20
pgrep -a "kwin_wayland|plasmashell|dbus-daemon" | cut -c1-120
