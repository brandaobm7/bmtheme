// Botões de janela no estilo do Mac: fechar, minimizar e maximizar. Do tamanho dos
// botões das outras janelas do tema. O símbolo aparece só no botão sob o mouse.
// Com a janela sem foco, os três ficam da cor apagada das janelas do sistema, e
// voltam a ter cor enquanto o mouse está sobre eles.
import QtQuick
import QtQuick.Controls
import QtQuick.Window

Row {
    id: botoes
    property Window alvo                    // a janela que os botões comandam
    property bool podeMaximizar: true       // sem maximizar, o terceiro botão fica cinza
    readonly property bool cheia: alvo.visibility === Window.Maximized || alvo.visibility === Window.FullScreen
    // Coloridos com a janela em uso ou com o mouse em cima do grupo.
    readonly property bool coloridos: alvo.active || sobre.hovered
    // A cor dos botões das janelas do sistema sem foco (decoracao/tingir.py).
    readonly property color apagado: sistema.escuro ? "#54507c" : "#d4d1e6"
    signal fechar()
    spacing: 10

    HoverHandler { id: sobre }

    Repeater {
        model: [{ cor: "#ff5f57", acao: "fechar", dica: "Fechar" },
                { cor: "#febc2e", acao: "minimizar", dica: "Minimizar" },
                { cor: "#28c840", acao: "maximizar", dica: botoes.cheia ? "Restaurar" : "Maximizar" }]
        delegate: Rectangle {
            id: botao
            required property var modelData
            readonly property bool ativo: modelData.acao !== "maximizar" || botoes.podeMaximizar
            readonly property color traco: Qt.rgba(0, 0, 0, 0.55)
            width: 16
            height: 16
            radius: 8
            color: !botoes.coloridos ? botoes.apagado
                 : ativo ? modelData.cor : (sistema.escuro ? Qt.rgba(1, 1, 1, 0.18) : "#d3d1dc")
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.1)

            // Símbolo: x para fechar, traço para minimizar e + para maximizar.
            Item {
                anchors.centerIn: parent
                width: 9
                height: 9
                visible: area.containsMouse && botao.ativo
                rotation: botao.modelData.acao === "fechar" ? 45 : 0
                Rectangle { anchors.centerIn: parent; width: 9; height: 1.8; radius: 0.9; color: botao.traco }
                Rectangle {
                    visible: botao.modelData.acao !== "minimizar"
                    anchors.centerIn: parent
                    width: 1.8
                    height: 9
                    radius: 0.9
                    color: botao.traco
                }
            }
            MouseArea {
                id: area
                anchors.fill: parent
                anchors.margins: -3
                hoverEnabled: true
                onClicked: {
                    if (!botao.ativo)
                        return
                    if (botao.modelData.acao === "fechar")
                        botoes.fechar()
                    else if (botao.modelData.acao === "minimizar")
                        botoes.alvo.showMinimized()
                    else
                        botoes.cheia ? botoes.alvo.showNormal() : botoes.alvo.showMaximized()
                }
            }
            ToolTip.visible: area.containsMouse && botao.ativo
            ToolTip.delay: 600
            ToolTip.text: modelData.dica
        }
    }
}
