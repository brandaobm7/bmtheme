#!/bin/bash
# Compila o motor da decoração das janelas (Aurorae) com as trocas que arredondam
# os cantos de baixo (cantos-da-decoracao.py).
#
# Roda numa etapa à parte da construção da imagem (ver imagem/Containerfile), que é
# jogada fora: os pacotes instalados para compilar nunca chegam à imagem final, que
# recebe só o arquivo pronto. Se algo falhar, o arquivo entregue é o original, e a
# decoração fica como a do Plasma.
#
# Uso: cantos-da-decoracao.sh PASTA_DE_SAIDA
set -uo pipefail
AQUI="$(cd "$(dirname "$0")" && pwd)"
SAIDA="${1:?diga a pasta de saída}"
# As duas versões do motor: o KWin usa uma ou outra para o mesmo tema.
PECAS="org.kde.kwin.aurorae.so org.kde.kwin.aurorae.v2.so"
ONDE=/usr/lib64/qt6/plugins/org.kde.kdecoration3
mkdir -p "$SAIDA"
# Os originais ficam guardados antes de qualquer instalação.
for peca in $PECAS; do
  [ -f "$ONDE/$peca" ] || { echo "Erro: esta imagem não tem o Aurorae ($peca)." >&2; exit 1; }
  cp -p "$ONDE/$peca" "$SAIDA/$peca"
done

# As bibliotecas com que a peça conversa. Se a instalação dos pacotes de compilação
# atualizar alguma, a peça sairia feita para uma versão que a imagem final não tem.
versoes() {
  rpm -q --qf '%{NAME}-%{VERSION}-%{RELEASE}\n' aurorae kdecoration kwin qt6-qtbase qt6-qtdeclarative \
    kf6-kconfig kf6-kcoreaddons kf6-ki18n kf6-kpackage kf6-ksvg kf6-kwindowsystem kf6-kcolorscheme | sort
}

compilar() {
  set -e
  OBRA="$(mktemp -d)"
  cd "$OBRA"
  versoes >antes
  # O que o pacote do Aurorae pede para ser compilado (do arquivo .spec dele).
  dnf5 -y -q install --setopt=install_weak_deps=False cmake gcc-c++ extra-cmake-modules cpio \
    'cmake(Qt6Core)' 'cmake(Qt6DBus)' 'cmake(Qt6Quick)' 'cmake(Qt6UiTools)' 'cmake(Qt6Widgets)' \
    'cmake(KF6ColorScheme)' 'cmake(KF6Config)' 'cmake(KF6CoreAddons)' 'cmake(KF6I18n)' 'cmake(KF6KCMUtils)' \
    'cmake(KF6NewStuff)' 'cmake(KF6Package)' 'cmake(KF6Svg)' 'cmake(KF6WindowSystem)' 'cmake(KDecoration3)' >/dev/null
  versoes >depois
  if ! cmp -s antes depois; then
    echo "A instalação atualizou bibliotecas que a decoração usa:" >&2
    diff antes depois >&2 || true
    return 1
  fi
  # O código da mesma versão que está instalada.
  dnf5 -y -q download --source aurorae >/dev/null
  rpm2cpio aurorae-*.src.rpm | cpio -idm --quiet
  tar -xf aurorae-*.tar.xz
  codigo="aurorae-$(rpm -q --qf '%{VERSION}' aurorae)"
  [ -d "$codigo" ] || { echo "O código baixado não é da versão instalada." >&2; return 1; }
  python3 "$AQUI/cantos-da-decoracao.py" "$codigo"
  cmake -S "$codigo" -B obra -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr \
    -DKDE_INSTALL_USE_QT_SYS_PATHS=ON -DBUILD_TESTING=OFF >cmake.log 2>&1 || { tail -30 cmake.log >&2; return 1; }
  cmake --build obra --target aurorae_v1 aurorae_v2 -j"$(nproc)" >compilar.log 2>&1 || { tail -40 compilar.log >&2; return 1; }
  # Só troca os originais guardados depois de as duas peças existirem.
  for peca in $PECAS; do
    [ -n "$(find obra -name "$peca" | head -1)" ] || { echo "A compilação não gerou $peca." >&2; return 1; }
  done
  for peca in $PECAS; do
    novo="$(find obra -name "$peca" | head -1)"
    strip --strip-unneeded "$novo" 2>/dev/null || true
    install -m 755 "$novo" "$SAIDA/$peca"
  done
}

if (compilar); then
  echo "Decoração das janelas compilada com os cantos de baixo arredondados."
else
  echo "Aviso: não consegui compilar a decoração com os cantos de baixo arredondados. Ela fica como a do Plasma." >&2
fi
