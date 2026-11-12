#!/usr/bin/env bash
# Gera o papel de parede da tela de bloqueio a partir do papel de parede do bmos.
# É o mesmo desenho, um pouco mais escuro e menos colorido, para o relógio
# branco da tela de bloqueio do Plasma ficar legível.
# Precisa do ImageMagick (comando "magick").
# Uso: ferramentas/gerar-fundo-bloqueio.sh
set -euo pipefail
AQUI="$(cd "$(dirname "$0")/.." && pwd)"
ORIGEM="$AQUI/papel-de-parede/bmos/contents"
DESTINO="$AQUI/papel-de-parede/bmos-bloqueio/contents"
mkdir -p "$DESTINO/images" "$DESTINO/images_dark"
# Claro: 22% de preto por cima e 25% menos cor.
magick "$ORIGEM/images/3840x2400.png" -fill black -colorize 22 -modulate 100,75 -strip "$DESTINO/images/3840x2400.png"
# Escuro: já é escuro. Só 12% de preto por cima.
magick "$ORIGEM/images_dark/3840x2400.png" -fill black -colorize 12 -strip "$DESTINO/images_dark/3840x2400.png"
echo "Papel de parede da tela de bloqueio gerado em $DESTINO"
