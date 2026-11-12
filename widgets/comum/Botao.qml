// Botão de texto do bmos: azul-violeta quando é o principal, claro quando não é.
import QtQuick

Rectangle {
    id: botao

    property string text: ""
    property bool principal: true
    signal clicked()

    Paleta { id: paleta }

    implicitWidth: rotulo.implicitWidth + 28
    implicitHeight: 36
    radius: 11
    opacity: enabled ? 1 : 0.5
    color: principal ? (area.containsMouse ? paleta.destaqueSobre : paleta.destaque)
                     : (area.containsMouse ? paleta.botaoSobre : paleta.botao)

    Texto {
        id: rotulo
        anchors.centerIn: parent
        text: botao.text
        font.weight: Font.Medium
        color: botao.principal ? "#ffffff" : paleta.texto
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: botao.clicked()
    }
}
