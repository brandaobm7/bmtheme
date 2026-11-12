#!/usr/bin/env bash
# Roda dentro da construção da imagem bmos, como administrador, sobre o Bazzite.
# Põe os componentes do tema no sistema, tira os apps e serviços que não servem
# e deixa o tema pronto para ser aplicado no login de cada usuário.
set -euo pipefail

TEMA=/usr/share/bmtheme
AQUI="$TEMA/imagem"
passo() { printf '\n==> %s\n' "$*"; }
# linhas FICHEIRO: as linhas de uma lista, sem comentários nem linhas vazias.
linhas() { grep -v -E '^\s*(#|$)' "$1" || true; }

# Nestas imagens a pasta do administrador (/root) aponta para /var, que não existe
# durante a construção. O que os instaladores guardam em cache vai para uma pasta temporária.
export HOME="$(mktemp -d)"

passo "Kvantum: o motor que desenha os menus e controles dos apps do KDE"
# Não vem no Bazzite. Com ele, os menus do sistema ganham o desenho do menu do Arquivos.
dnf5 -y install kvantum

passo "Componentes de terceiros no sistema: fonte, ícones, decoração, menus, tema GTK e PySide6"
bash "$TEMA/instalar.sh" --componentes-do-sistema

# ------------------------------------------------------------------ limpeza
passo "Limpeza: pacotes"
sair=()
while read -r padrao; do
  while read -r nome; do
    [ -n "$nome" ] && sair+=("$nome")
  done < <(rpm -qa --qf '%{NAME}\n' "$padrao" | sort -u)
done < <(linhas "$AQUI/remover.txt")
if [ "${#sair[@]}" -gt 0 ]; then
  printf 'Saem: %s\n' "${sair[*]}"
  rpm -qa --qf '%{NAME}\n' | sort -u >"$HOME/antes"
  bash "$AQUI/restos.sh" antes "${sair[@]}"
  dnf5 -y remove --no-autoremove "${sair[@]}"
  rpm -qa --qf '%{NAME}\n' | sort -u >"$HOME/depois"
  # Tirar um pacote leva junto quem depende dele. Se saiu qualquer coisa além da
  # lista, a construção para aqui: o item da lista é dependência de algo que fica.
  a_mais="$(comm -23 "$HOME/antes" "$HOME/depois" | grep -v -x -F -f <(printf '%s\n' "${sair[@]}") || true)"
  if [ -n "$a_mais" ]; then
    printf 'Erro: a limpeza tirou pacotes que não estão na lista:\n%s\n' "$a_mais" >&2
    exit 1
  fi

  passo "Limpeza: restos dos pacotes removidos"
  bash "$AQUI/restos.sh" depois
fi

passo "Limpeza: padrões que apontavam para apps removidos"
# O ujust carrega uma lista de receitas. A de um app removido saiu acima: a linha
# que a carrega sai junto, ou o ujust inteiro para de funcionar.
receitas=/usr/share/ublue-os/justfile
if [ -f "$receitas" ]; then
  while IFS= read -r arquivo; do
    [ -e "$arquivo" ] && continue
    sed -i "\|^import \"$arquivo\"|d" "$receitas"
    echo "  receita descarregada: $arquivo"
  done < <(sed -n 's/^import "\(.*\)"$/\1/p' "$receitas")
  ujust --list >/dev/null || { echo "Erro: o ujust parou de funcionar depois da limpeza." >&2; exit 1; }
fi
# App padrão de cada tipo de arquivo: navegador e PDF no Chrome, texto no KWrite.
for lista in /usr/share/applications/mimeapps.list /usr/share/applications/kde-mimeapps.list \
             /etc/xdg/mimeapps.list /usr/share/kde-settings/kde-profile/default/xdg/kde-mimeapps.list; do
  [ -f "$lista" ] || continue
  sed -i -e 's/org\.mozilla\.firefox\.desktop/com.google.Chrome.desktop/g' \
         -e '/^application\/pdf=/s/org\.kde\.okular\.desktop/com.google.Chrome.desktop/' \
         -e 's/org\.kde\.okular[A-Za-z_.]*\.desktop;\?//g' \
         -e 's/org\.kde\.kate\.desktop;\?//g' \
         -e 's/org\.kde\.kdeconnect[A-Za-z_.]*\.desktop;\?//g' \
         -e '/^[^=[]*=$/d' "$lista"
done
# Favoritos do menu de apps do Plasma.
favoritos=/usr/share/kde-settings/kde-profile/default/xdg/kicker-extra-favoritesrc
[ -f "$favoritos" ] && sed -i -e 's/net\.lutris\.Lutris\.desktop;//' -e 's/io\.github\.ublue_os\.yafti_gtk\.desktop;//' "$favoritos"

passo "Limpeza: apps em Flatpak"
# Os Flatpaks não ficam dentro da imagem: são instalados na máquina. Este serviço
# roda no boot e põe os apps do bmos e tira os que saem, uma única vez cada um.
install -m 755 "$AQUI/bmtheme-flatpaks" /usr/libexec/bmtheme-flatpaks
install -m 644 "$AQUI/bmtheme-flatpaks.service" /usr/lib/systemd/system/bmtheme-flatpaks.service
systemctl enable bmtheme-flatpaks.service
# A lista abaixo é a que o instalador do Bazzite usa para os apps que já vêm no disco.
lista=/usr/share/ublue-os/bazzite/flatpak/install
if [ -f "$lista" ]; then
  while read -r app; do
    sed -i "/^$(printf '%s' "$app" | sed 's/\./\\./g')\$/d" "$lista"
  done < <(linhas "$AQUI/flatpaks-sair.txt")
  while read -r app; do
    grep -q -x -F "$app" "$lista" || echo "$app" >>"$lista"
  done < <(linhas "$AQUI/flatpaks-entrar.txt")
  echo "Lista de apps do instalador:"
  cat "$lista"
else
  echo "Aviso: esta versão do Bazzite não tem a lista $lista. Segue sem ela." >&2
fi

passo "Limpeza: atalhos e serviços"
# esconder ATALHO: um atalho que não é de pacote nenhum é apagado; o de um pacote só some do menu.
esconder() {
  local atalho="/usr/share/applications/$1"
  [ -f "$atalho" ] || return 0
  if rpm -qf "$atalho" >/dev/null 2>&1; then
    grep -q '^NoDisplay=' "$atalho" || sed -i '0,/^\[Desktop Entry\]/s//[Desktop Entry]\nNoDisplay=true/' "$atalho"
  else
    rm -f "$atalho"
  fi
}
# O assistente inicial do Bazzite mudou de nome entre as versões: entram os dois.
for atalho in bazzite-documentation.desktop discourse.desktop yafti-go.desktop io.github.ublue_os.yafti_gtk.desktop \
              waydroid-container-restart.desktop org.kde.kmenuedit.desktop org.kde.plasma.emojier.desktop; do
  esconder "$atalho"
done
# Atalhos do Waydroid que o Bazzite acrescenta por fora do pacote.
rm -rf /usr/share/applications/[Ww]aydroid*
systemctl disable input-remapper.service brew-setup.service 2>/dev/null || true
systemctl --global disable podman.socket 2>/dev/null || true

# Teclado virtual do Plasma: continua instalado, porque a tela de login depende
# dele, mas não é mais iniciado na área de trabalho. O Big Picture usa o da Steam.
for arquivo in /usr/share/kde-settings/kde-profile/default/xdg/kwinrc /etc/xdg/kwinrc; do
  [ -f "$arquivo" ] && sed -i '/^InputMethod/d' "$arquivo"
done

# Carteira de senhas desligada. A senha do Wi-Fi fica guardada pelo sistema de rede.
printf '[Wallet]\nEnabled=false\n' >/etc/xdg/kwalletrc
rm -f /etc/xdg/autostart/pam_kwallet_init.desktop

# ------------------------------------------------------------------ ajustes de hardware
passo "Bluetooth: o adaptador não dorme"
# Por padrão o adaptador Bluetooth por USB dorme depois de 2 segundos sem uso.
# Dormindo, ele não ouve o mouse ou o teclado chamar quando o computador volta
# da suspensão, e o aparelho não reconecta sozinho.
echo "options btusb enable_autosuspend=n" >/usr/lib/modprobe.d/bmos-btusb.conf

# ------------------------------------------------------------------ tema no login
passo "Tema aplicado no login de cada usuário"
install -m 755 "$AQUI/primeiro-uso.sh" /usr/libexec/bmtheme-primeiro-uso
install -m 644 "$AQUI/bmtheme-primeiro-uso.desktop" /etc/xdg/autostart/bmtheme-primeiro-uso.desktop
chmod 755 "$TEMA/instalar.sh" "$TEMA/desinstalar.sh" "$TEMA"/bin/*
# Assinatura do tema: muda quando qualquer arquivo dele muda. É por ela que o
# login de cada usuário sabe que precisa aplicar o tema de novo. A receita da
# imagem fica de fora, para uma mudança só nela não reaplicar o tema à toa.
(cd "$TEMA" && find . -type f ! -path './imagem/*' ! -name assinatura -print0 | sort -z | xargs -0 sha256sum | sha256sum | cut -c1-16) >"$TEMA/assinatura"
echo "Assinatura do tema: $(cat "$TEMA/assinatura")"
# Restos dos apps removidos na pasta pessoal: cada usuário apaga os seus, vendo a lista.
install -m 755 "$AQUI/limpar-restos" /usr/bin/bmos-limpar-restos

passo "Faxina da construção"
dnf5 clean all >/dev/null 2>&1 || true
rm -rf /tmp/* /var/tmp/* /var/cache/dnf /var/cache/libdnf5 /var/lib/dnf /var/log/dnf5.log* /var/cache/ldconfig /run/dnf /run/selinux-policy
printf '\nImagem bmos pronta, com o tema na versão %s.\n' "$(cat "$TEMA/VERSAO")"
