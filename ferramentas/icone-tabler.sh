#!/usr/bin/env bash
# Acrescenta ao tema um ou mais ícones de traço do Tabler Icons (licença MIT),
# nas cores e na espessura dos que já estão aqui.
#
#   icones-tabler/NOME.svg                        traço branco, para os widgets do Plasma
#   app-comum/icones/NOME-{branco,cinza,destaque,escuro}.svg   para o Arquivos e o Ajustes
#
# Os nomes são os do site https://tabler.io/icons (estilo "outline").
# Uso: ferramentas/icone-tabler.sh NOME [NOME...]     Precisa de internet.
set -euo pipefail

VERSAO=3.51.0          # a mesma dos ícones que já estão no tema
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
[ "$#" -gt 0 ] || { sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }
ORIGEM="$(mktemp -d)"
trap 'rm -rf "$ORIGEM"' EXIT

# colorir ORIGEM DESTINO COR: troca a cor do traço, afina o traço e tira o que o Tabler põe a mais.
colorir() {
  sed -e "s/currentColor/$3/g" -e 's/stroke-width="2"/stroke-width="1.75"/' \
      -e '/class="icon/d' -e '/<path stroke="none" d="M0 0h24v24H0z" fill="none" *\/>/d' "$1" >"$2"
}

for nome in "$@"; do
  curl -fsS -o "$ORIGEM/$nome.svg" "https://cdn.jsdelivr.net/npm/@tabler/icons@$VERSAO/icons/outline/$nome.svg" \
    || { echo "Erro: não achei o ícone \"$nome\" no Tabler $VERSAO." >&2; exit 1; }
  colorir "$ORIGEM/$nome.svg" "$RAIZ/icones-tabler/$nome.svg" "#ffffff"
  colorir "$ORIGEM/$nome.svg" "$RAIZ/app-comum/icones/$nome-branco.svg" "#ffffff"
  colorir "$ORIGEM/$nome.svg" "$RAIZ/app-comum/icones/$nome-cinza.svg" "#6b6880"
  colorir "$ORIGEM/$nome.svg" "$RAIZ/app-comum/icones/$nome-destaque.svg" "#5f6be6"
  colorir "$ORIGEM/$nome.svg" "$RAIZ/app-comum/icones/$nome-escuro.svg" "#1f1d2b"
  echo "Ícone $nome acrescentado."
done
