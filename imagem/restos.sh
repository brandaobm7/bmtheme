#!/usr/bin/env bash
# Tira o que os pacotes removidos deixam para trás no sistema: configuração alterada,
# pastas com arquivos criados depois da instalação, atalhos que passam a apontar para
# o nada, contas de serviço e arquivos soltos com o nome do app.
#
# Roda em duas partes, em volta da remoção dos pacotes:
#   restos.sh antes PACOTE...   anota o que os pacotes têm e o que já estava quebrado
#   restos.sh depois            apaga o que sobrou
#
# Regra de segurança: só sai o que nenhum pacote que ficou declara como seu. O que
# pertence a outro pacote só sai se estiver escrito em restos-de-outros.txt.
set -euo pipefail

AQUI="$(cd "$(dirname "$0")" && pwd)"
NOTAS="${NOTAS:-$HOME/restos}"
# Onde procurar. Ficam de fora os módulos do kernel, os Flatpaks e o próprio tema.
PASTAS=(/etc /usr/bin /usr/sbin /usr/lib /usr/lib64 /usr/libexec /usr/share /usr/local /opt /var/lib)
FORA=(/usr/lib/modules /usr/lib/bmtheme /usr/share/bmtheme '/usr/share/icons/MacTahoe*' /var/lib/flatpak /var/lib/rpm /usr/lib/sysimage)
# Pastas do próprio sistema, que nunca saem.
FIXAS=" / /etc /usr /usr/bin /usr/sbin /usr/lib /usr/lib64 /usr/libexec /usr/share /usr/local /opt /var /var/lib "
shopt -s nullglob

linhas() { grep -v -E '^\s*(#|$)' "$1" 2>/dev/null || true; }
sem_dono() { ! rpm -qf "$1" >/dev/null 2>&1; }
# Uma pasta só de restos: nada dentro dela pertence a um pacote que ficou.
so_restos() {
  local item
  while IFS= read -r -d '' item; do
    sem_dono "$item" || return 1
  done < <(find "$1" -mindepth 1 -print0 2>/dev/null)
  return 0
}
existe() { [ -e "$1" ] || [ -L "$1" ]; }
fixa() { case "$FIXAS" in *" $1 "*) return 0 ;; esac; return 1; }
apagar() {
  fixa "$1" && return 0
  rm -rf -- "$1"
  echo "  saiu: $1"
  # A pasta que ficou vazia e sem dono sai junto.
  local pai
  pai="$(dirname "$1")"
  while [ -d "$pai" ] && ! fixa "$pai" && [ -z "$(ls -A "$pai")" ] && sem_dono "$pai"; do
    rmdir "$pai" && echo "  saiu: $pai (vazia)"
    pai="$(dirname "$pai")"
  done
}
# Sai se não tem dono. Uma pasta sai só se tudo dentro dela também for resto.
apagar_se_resto() {
  existe "$1" || return 0
  sem_dono "$1" || return 0
  if [ -d "$1" ] && [ ! -L "$1" ] && ! so_restos "$1"; then
    return 0
  fi
  apagar "$1"
}
procurar() {
  local poda=() onde=() pasta
  for pasta in "${FORA[@]}"; do
    poda+=(-path "$pasta" -o)
  done
  for pasta in "${PASTAS[@]}"; do
    [ -d "$pasta" ] && onde+=("$pasta")
  done
  # O find reclama de itens que somem ou que não pode ler: isso não para a limpeza.
  { find "${onde[@]}" \( "${poda[@]}" -false \) -prune -o "$@" -print 2>/dev/null || true; } | sort
}
contas_de() {   # nomes de usuários e grupos que os arquivos do sysusers declaram
  [ "$#" -gt 0 ] || return 0
  awk '$1 ~ /^[ug]/ && $2 !~ /^-/ {print $2}' "$@" 2>/dev/null | sort -u || true
}

case "${1:-}" in
  antes)
    shift
    mkdir -p "$NOTAS"
    { rpm -ql "$@" 2>/dev/null || true; } | { grep '^/' || true; } | sort -u >"$NOTAS/arquivos"
    procurar -xtype l >"$NOTAS/atalhos-quebrados"
    # shellcheck disable=SC2046
    contas_de $(grep -E '^/usr/lib/sysusers\.d/.*\.conf$' "$NOTAS/arquivos" || true) >"$NOTAS/contas"
    ;;

  depois)
    echo "O que os pacotes deixaram:"
    # Do mais fundo para o mais raso, para a pasta ser vista depois do que há nela.
    sort -r "$NOTAS/arquivos" | while IFS= read -r caminho; do
      for resto in "$caminho" "$caminho.rpmsave" "$caminho.rpmnew" "$caminho.rpmorig"; do
        apagar_se_resto "$resto"
      done
    done

    echo "Atalhos que passaram a apontar para o nada:"
    procurar -xtype l | comm -13 "$NOTAS/atalhos-quebrados" - | while IFS= read -r atalho; do
      [ -L "$atalho" ] && apagar "$atalho"
    done

    echo "Contas de serviço que eram só deles:"
    contas_de /usr/lib/sysusers.d/*.conf /etc/sysusers.d/*.conf >"$NOTAS/contas-que-ficam"
    while IFS= read -r conta; do
      [ -n "$conta" ] || continue
      grep -q -x -F "$conta" "$NOTAS/contas-que-ficam" && continue
      if getent passwd "$conta" >/dev/null && userdel "$conta" 2>/dev/null; then echo "  saiu: usuário $conta"; fi
      if getent group "$conta" >/dev/null && groupdel "$conta" 2>/dev/null; then echo "  saiu: grupo $conta"; fi
    done <"$NOTAS/contas"

    echo "Arquivos de outros pacotes que só serviam aos apps removidos:"
    while IFS= read -r padrao; do
      for caminho in $padrao; do      # sem aspas: o padrão pode ter curinga
        existe "$caminho" && apagar "$caminho"
      done
    done < <(linhas "$AQUI/restos-de-outros.txt")

    echo "Arquivos soltos com o nome de um app removido:"
    : >"$NOTAS/citam"
    # Uma lista só de tudo o que há no sistema, e ao lado só o nome de cada item:
    # o padrão de restos.txt é comparado com o nome, não com o caminho.
    procurar >"$NOTAS/tudo"
    sed 's|.*/||' "$NOTAS/tudo" >"$NOTAS/nomes"
    while IFS= read -r nome; do
      grep -n -i -E -- "$nome" "$NOTAS/nomes" | cut -d: -f1 >"$NOTAS/achados" || true
      awk 'NR == FNR { achado[$1]; next } FNR in achado' "$NOTAS/achados" "$NOTAS/tudo" | while IFS= read -r caminho; do
        existe "$caminho" || continue
        if sem_dono "$caminho"; then
          apagar_se_resto "$caminho"
        else
          echo "$caminho" >>"$NOTAS/citam"
        fi
      done
    done < <(linhas "$AQUI/restos.txt")

    # O que ainda leva o nome de um app removido e pertence a um pacote que ficou.
    # Não é apagado sozinho: entra em restos-de-outros.txt depois de conferido.
    if [ -s "$NOTAS/citam" ]; then
      echo "Ficaram, por pertencerem a pacotes que continuam instalados:"
      sort -u "$NOTAS/citam" | while IFS= read -r caminho; do
        printf '  %s  (%s)\n' "$caminho" "$(rpm -qf --qf '%{NAME}' "$caminho" 2>/dev/null | head -1)"
      done
    fi
    ;;

  *)
    echo "Uso: restos.sh antes PACOTE... | restos.sh depois" >&2
    exit 2
    ;;
esac
