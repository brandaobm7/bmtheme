#!/usr/bin/env python3
"""Dá à tela de bloqueio do Plasma o desenho do bmos.

A tela de bloqueio faz parte do sistema (pacote plasma-desktop) e não aceita tema:
o desenho só muda trocando os arquivos dela, e por isso só a imagem bmos faz isso.
Em vez de substituir os arquivos por cópias nossas, que quebrariam a cada versão
do Plasma, este roteiro faz poucas trocas em cima dos originais:

  - o relógio fica no meio da tela enquanto ela descansa e vai para a esquerda
    quando aparece o campo de senha;
  - no lugar da foto, só o nome de quem está usando, acima do campo de senha;
  - saem os botões de suspender e trocar de usuário;
  - o botão de destravar mostra um cadeado aberto.

Segurança: ou todas as trocas encontram o trecho esperado, ou nenhum arquivo é
tocado e a tela de bloqueio fica como a do Plasma. Uma tela de bloqueio que não
carrega deixaria a pessoa sem conseguir destravar o computador.

Uso: tela-de-bloqueio.py [PASTA]   (padrão: a pasta da tela de bloqueio no sistema)
"""

import os
import sys

PASTA = "/usr/share/plasma/shells/org.kde.plasma.desktop/contents/lockscreen"

RELOGIO_DO_PLASMA = """        Clock {
            id: clock
            property Item shadow: clockShadow
            visible: y > 0 && config.alwaysShowClock
            anchors.horizontalCenter: parent.horizontalCenter
            y: (mainBlock.userList.y + mainStack.y)/2 - height/2
            Layout.alignment: Qt.AlignBaseline
        }
"""

RELOGIO_DO_BMOS = """        // Relógio do bmos: no meio da tela enquanto ela descansa; vai para a
        // esquerda quando aparece o campo de senha. (imagem/tela-de-bloqueio.py)
        Column {
            id: clock
            property Item shadow: clockShadow
            property date agora: new Date()
            readonly property bool deLado: lockScreenRoot.uiVisible
            visible: config.alwaysShowClock
            x: deLado ? Math.round(lockScreenRoot.width * 0.09) : Math.round((lockScreenRoot.width - width) / 2)
            y: Math.round((lockScreenRoot.height - height) / 2) - Kirigami.Units.gridUnit
            Behavior on x {
                NumberAnimation { duration: Kirigami.Units.veryLongDuration; easing.type: Easing.InOutQuad }
            }
            Timer {
                interval: 1000
                running: true
                repeat: true
                onTriggered: clock.agora = new Date()
            }
            Text {
                // No meio, a hora fica centrada sobre a data; de lado, as duas começam juntas.
                x: clock.deLado ? 0 : Math.round((clock.width - width) / 2)
                text: Qt.formatTime(clock.agora, "HH:mm")
                color: "white"
                font.pixelSize: Math.round(lockScreenRoot.height * 0.09)
                font.weight: Font.Light
                font.letterSpacing: 1
                font.features: { "tnum": 1 }
                renderType: Text.NativeRendering
                Behavior on x {
                    NumberAnimation { duration: Kirigami.Units.veryLongDuration; easing.type: Easing.InOutQuad }
                }
            }
            Text {
                x: clock.deLado ? 0 : Math.round((clock.width - width) / 2)
                // Em português, "quarta, 11 de novembro". Nos outros idiomas, a data longa de cada um.
                text: Qt.locale().name.startsWith("pt") ? clock.agora.toLocaleDateString(Qt.locale(), "dddd, d 'de' MMMM")
                                                        : clock.agora.toLocaleDateString(Qt.locale(), Locale.LongFormat)
                color: "white"
                font.pixelSize: Math.round(lockScreenRoot.height * 0.0215)
                renderType: Text.NativeRendering
                Behavior on x {
                    NumberAnimation { duration: Kirigami.Units.veryLongDuration; easing.type: Easing.InOutQuad }
                }
            }
        }
"""

NOME = """    // Nome de quem está usando o computador, acima do campo de senha, sem a foto.
    // (imagem/tela-de-bloqueio.py)
    PlasmaComponents3.Label {
        Layout.fillWidth: true
        Layout.bottomMargin: Kirigami.Units.largeSpacing
        horizontalAlignment: Text.AlignHCenter
        text: kscreenlocker_userName
        textFormat: Text.PlainText
        elide: Text.ElideRight
        font.pointSize: Kirigami.Theme.defaultFont.pointSize + 4
    }

    RowLayout {
        id: passwordLayout
"""

CAMPO = """            id: passwordBox
            font.pointSize: Kirigami.Theme.defaultFont.pointSize + 1
            implicitHeight: Math.round(Kirigami.Units.gridUnit * 2.2)
            leftPadding: Kirigami.Units.largeSpacing
            color: "white"
            placeholderTextColor: Qt.rgba(1, 1, 1, 0.6)
            background: Rectangle {
                radius: 10
                color: Qt.rgba(1, 1, 1, 0.16)
                border.width: passwordBox.activeFocus ? 2 : 1
                border.color: passwordBox.activeFocus ? "#7f8ff8" : Qt.rgba(1, 1, 1, 0.28)
            }
"""

BOTAO = """            id: loginButton
            icon.color: "white"
            background: Rectangle {
                radius: 10
                color: loginButton.hovered || loginButton.activeFocus ? Qt.rgba(1, 1, 1, 0.26) : Qt.rgba(1, 1, 1, 0.16)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.28)
            }
"""

# arquivo: [(trecho do Plasma, trecho do bmos), ...]. Cada trecho tem de aparecer uma vez só.
TROCAS = {
    "LockScreenUi.qml": [
        (RELOGIO_DO_PLASMA, RELOGIO_DO_BMOS),
        # Sem a foto e a lista de usuários: o nome vai junto do campo de senha.
        ("                showUserList: userList.y + mainStack.y > 0\n",
         "                showUserList: false\n                actionItemsVisible: false\n"),
        # O bloco do campo de senha sobe, para ficar na altura do relógio.
        ("            height: lockScreenRoot.height + Kirigami.Units.gridUnit * 3\n",
         "            height: lockScreenRoot.height + Kirigami.Units.gridUnit * 3\n"
         "            y: -Kirigami.Units.gridUnit * 6\n"),
    ],
    "MainBlock.qml": [
        ("    RowLayout {\n        id: passwordLayout\n", NOME),
        # Campo de senha de vidro, com o fio azul-violeta quando está em uso.
        ("            id: passwordBox\n            font.pointSize: Kirigami.Theme.defaultFont.pointSize + 1\n", CAMPO),
        # Botão de destravar no mesmo vidro.
        ("            id: loginButton\n", BOTAO),
        ('            icon.name: LayoutMirroring.enabled ? "go-previous" : "go-next"\n',
         '            icon.name: "object-unlocked"\n'),
    ],
}


def principal():
    pasta = sys.argv[1] if len(sys.argv) > 1 else PASTA
    novos = {}
    for nome, trocas in TROCAS.items():
        caminho = os.path.join(pasta, nome)
        try:
            with open(caminho, encoding="utf-8") as arquivo:
                texto = arquivo.read()
        except OSError:
            print(f"Aviso: não achei {caminho}. A tela de bloqueio fica como a do Plasma.", file=sys.stderr)
            return 0
        if "imagem/tela-de-bloqueio.py" in texto:
            print("A tela de bloqueio já está com o desenho do bmos.")
            return 0
        for do_plasma, do_bmos in trocas:
            if texto.count(do_plasma) != 1:
                print(f"Aviso: o {nome} desta versão do Plasma mudou e não aceita o desenho do bmos.\n"
                      "Nenhum arquivo foi alterado: a tela de bloqueio fica como a do Plasma.\n"
                      f"Trecho não encontrado:\n{do_plasma}", file=sys.stderr)
                return 0
            texto = texto.replace(do_plasma, do_bmos)
        novos[caminho] = texto
    for caminho, texto in novos.items():
        with open(caminho, "w", encoding="utf-8") as arquivo:
            arquivo.write(texto)
    print("Tela de bloqueio com o desenho do bmos.")
    return 0


if __name__ == "__main__":
    sys.exit(principal())
