#!/usr/bin/env python3
"""Corrige a tela de bloqueio do Plasma para conta sem senha.

Numa conta sem senha, o Plasma libera a tela sem pedir nada e troca o campo de
senha por um botão "Desbloquear". Só que, quando a tela é recriada (ao voltar da
suspensão, por exemplo), ela volta a mostrar o campo de senha, e a conferência,
que já foi feita e encerrada, não começa de novo: Enter não faz nada e a pessoa
fica presa do lado de fora. Visto no Plasma 6.8.2, com e sem o tema.

A correção é uma troca só, em cima do arquivo do Plasma: a tela recriada confere
se a conta já foi liberada sem pedir senha e, se foi, já nasce com o botão
"Desbloquear". O desenho da tela não muda.

Segurança: se o trecho esperado não estiver no arquivo, nada é alterado e a tela
fica como a do Plasma. Para conta com senha nada muda: nela a tela nunca é
liberada sem a senha.

Uso: bloqueio-sem-senha.py [PASTA]   (padrão: a pasta da tela de bloqueio no sistema)
"""

import os
import sys

PASTA = "/usr/share/plasma/shells/org.kde.plasma.desktop/contents/lockscreen"
ARQUIVO = "LockScreenUi.qml"
MARCA = "imagem/bloqueio-sem-senha.py"

DO_PLASMA = """    property string pendingPassword
"""

DO_BMOS = """    property string pendingPassword

    // Conta sem senha: uma tela recriada depois de a conta já ter sido liberada
    // nasce com o botão "Desbloquear", e não com o campo de senha, que não teria
    // mais como conferir nada. (imagem/bloqueio-sem-senha.py)
    Component.onCompleted: {
        if (authenticator.unlocked && !authenticator.hadPrompt) {
            mainStack.replace(null, Qt.resolvedUrl("NoPasswordUnlock.qml"),
                { userListModel: users }, StackView.Immediate);
            mainStack.forceActiveFocus();
        }
    }
"""


def principal():
    pasta = sys.argv[1] if len(sys.argv) > 1 else PASTA
    caminho = os.path.join(pasta, ARQUIVO)
    try:
        with open(caminho, encoding="utf-8") as arquivo:
            texto = arquivo.read()
    except OSError:
        print(f"Aviso: não achei {caminho}. A tela de bloqueio fica como a do Plasma.", file=sys.stderr)
        return 0
    if MARCA in texto:
        print("A tela de bloqueio já tem a correção para conta sem senha.")
        return 0
    # O que a correção usa tem de existir nesta versão do Plasma.
    precisa = (DO_PLASMA, "id: mainStack", "NoPasswordUnlock.qml", "userListModel: users", "authenticator.hadPrompt")
    if texto.count(DO_PLASMA) != 1 or any(parte not in texto for parte in precisa) \
            or "\n    Component.onCompleted" in texto:
        print(f"Aviso: o {ARQUIVO} desta versão do Plasma mudou e não aceita a correção para conta sem senha.\n"
              "Nada foi alterado: a tela de bloqueio fica como a do Plasma.", file=sys.stderr)
        return 0
    with open(caminho, "w", encoding="utf-8") as arquivo:
        arquivo.write(texto.replace(DO_PLASMA, DO_BMOS))
    print("Tela de bloqueio com a correção para conta sem senha.")
    return 0


if __name__ == "__main__":
    sys.exit(principal())
