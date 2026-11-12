#!/bin/bash
# Testa a imagem bmos sem reiniciar o computador. Sobe, num contêiner da imagem,
# uma sessão do Plasma sem tela com um usuário novo, e roda os roteiros desta pasta:
#   aplicar.sh   o primeiro login: o tema deve ser aplicado sozinho
#   conferir.sh  segundo login, testes dos apps, janelas e modo escuro
#   ciclo.sh     desinstalar, e o login seguinte não deve reinstalar
# As capturas e os registros ficam em ./saida-da-sessao.
#
# Uso, num Bazzite com podman, na pasta do repositório:
#   testes/sessao-na-imagem/rodar.sh [IMAGEM] [roteiro...]
set -euo pipefail

IMAGEM="${1:-ghcr.io/brandaobm7/bmtheme-nvidia:latest}"
[ "$#" -gt 0 ] && shift
[ "$#" -gt 0 ] || set -- aplicar.sh conferir.sh ciclo.sh
AQUI="$(cd "$(dirname "$0")" && pwd)"
TEMA="$(cd "$AQUI/../.." && pwd)"
SAIDA="$PWD/saida-da-sessao"
NOME=bmtheme-sessao

podman rm -f -t 2 "$NOME" >/dev/null 2>&1 || true
podman unshare rm -rf "$SAIDA" 2>/dev/null || true
mkdir -p "$SAIDA" && chmod 777 "$SAIDA"

# --init e --pids-limit: sem eles os processos que morrem se acumulam e a sessão trava.
# As duas capacidades são as que o KWin pede para iniciar.
# A placa de vídeo integrada desenha a sessão; a NVIDIA não entra no contêiner.
placa=()
[ -e /dev/dri/renderD128 ] && placa=(--device /dev/dri/renderD128)
podman run -d --init --pids-limit=-1 --name "$NOME" --cap-add=SYS_NICE,SYS_RESOURCE "${placa[@]}" \
  -v "$AQUI:/teste:ro,Z" -v "$SAIDA:/saida:Z" -v "$TEMA:/fonte:ro,Z" "$IMAGEM" sleep 3600 >/dev/null
trap 'podman rm -f -t 2 "$NOME" >/dev/null 2>&1' EXIT

# O serviço de troca de arquivos por Bluetooth fica reiniciando sem parar num contêiner.
podman exec "$NOME" bash -c 'mkdir -p /var/home && useradd -m -d /var/home/teste -s /bin/bash teste
  chmod 777 /saida; rm -f /usr/share/dbus-1/services/org.bluez.obex.service'
podman exec -u teste "$NOME" bash /teste/subir.sh
for roteiro in "$@"; do
  printf '\n######## %s\n' "$roteiro"
  podman exec -u teste "$NOME" bash "/teste/$roteiro" 2>&1 | grep -v "org.bluez"
done
printf '\nCapturas e registros em %s\n' "$SAIDA"
