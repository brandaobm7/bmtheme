#!/bin/bash
. ~/ambiente
export QT_FORCE_STDERR_LOGGING=1
cd ~
QD=qdbus-qt6
spectacle -b -n -f -o /saida/1-antes.png >/dev/null 2>&1; ls -la /saida/1-antes.png 2>&1
pgrep -a "kwin_wayland|plasmashell" | cut -c1-60
echo "== primeiro uso"
time /usr/libexec/bmtheme-primeiro-uso
echo "saida do primeiro uso: $?"
cat ~/.local/state/bmtheme-instalacao.log
sleep 12
spectacle -b -n -f -o /saida/2-tema.png >/dev/null 2>&1; ls -la /saida/2-tema.png 2>&1
pgrep -a "kwin_wayland|plasmashell" | cut -c1-60
echo "== estado"
kreadconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage
$QD org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "var s=\"\"; var p=panels(); for (var i=0;i<p.length;i++){ s+=p[i].location+\" h=\"+p[i].height+\": \"; var w=p[i].widgets(); for (var j=0;j<w.length;j++) s+=w[j].type+\" \"; s+=\"\\n\"; } print(s)"
echo "== avisos da área de trabalho sobre o tema"
grep -iE "bmos" /saida/plasmashell.log | sed -E "s/^[^ ]+ //" | sort | uniq -c | sort -rn | head -40 | cut -c1-250
