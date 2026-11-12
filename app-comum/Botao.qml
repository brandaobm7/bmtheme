// Botão de texto: principal em azul-violeta, secundário em vidro claro.
import QtQuick
import QtQuick.Controls

Button {
    id: botao
    property bool principal: true
    implicitHeight: 36
    font.family: "Inter"
    font.pixelSize: 13
    font.weight: Font.DemiBold
    hoverEnabled: true
    contentItem: Text {
        text: botao.text
        font: botao.font
        color: botao.principal ? "#ffffff" : (sistema.escuro ? "#f2f0fa" : "#1f1d2b")
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        opacity: botao.enabled ? 1 : 0.5
    }
    background: Rectangle {
        implicitWidth: 112
        radius: 11
        color: botao.principal ? (botao.hovered ? "#6b77ec" : "#5f6ce5")
                               : (sistema.escuro ? Qt.rgba(1, 1, 1, botao.hovered ? 0.2 : 0.12)
                                                 : Qt.rgba(1, 1, 1, botao.hovered ? 0.95 : 0.75))
        border.width: botao.principal ? 0 : 1
        border.color: sistema.escuro ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0.43, 0.41, 0.63, 0.2)
        opacity: botao.enabled ? 1 : 0.55
    }
}
