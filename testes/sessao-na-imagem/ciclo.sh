#!/bin/bash
. ~/ambiente
cd ~
paineis() { qdbus-qt6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "var s=\"\"; var p=panels(); for (var i=0;i<p.length;i++){ s+=p[i].location+\" h=\"+p[i].height+\": \"; var w=p[i].widgets(); for (var j=0;j<w.length;j++) s+=w[j].type+\" \"; s+=\"\\n\"; } print(s)"; }
echo "== instalar"; ( time /usr/share/bmtheme/instalar.sh claro ) 2>&1 | grep -E "real|Não foi|instalado"
sleep 8; paineis; grep "^launchers=" ~/.config/plasma-org.kde.plasma.desktop-appletsrc | cut -c1-300
timeout 20 spectacle -b -n -f -o /saida/2-tema.png >/dev/null 2>&1
echo "== desinstalar"; ( time /usr/share/bmtheme/desinstalar.sh ) 2>&1 | grep -E "real|removido"
sleep 10; paineis; ls ~/.config/bmos/ ~/.local/share/bmos-tema 2>&1 | tr "\n" " "; echo
timeout 20 spectacle -b -n -f -o /saida/6-desinstalado.png >/dev/null 2>&1
echo "== login depois de desinstalar"; ( time /usr/libexec/bmtheme-primeiro-uso ) 2>&1 | grep real; ls ~/.local/share/bmos-tema 2>&1 | head -1
ls -la /saida/*.png
