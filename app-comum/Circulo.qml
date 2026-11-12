// Botão redondo com ícone Tabler: azul-violeta quando ligado, branco quando desligado.
import QtQuick
import QtQuick.Controls

Item {
    id: circulo
    property string nome: ""
    property bool ligado: false
    property int tamanho: 44
    property string dica: ""
    signal clicado()
    implicitWidth: tamanho
    implicitHeight: tamanho

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 2
        anchors.bottomMargin: -2
        radius: width / 2
        color: Qt.rgba(0.23, 0.2, 0.45, circulo.ligado ? 0.16 : 0.07)
    }
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: sistema.escuro ? Qt.rgba(1, 1, 1, area.containsMouse ? 0.2 : 0.12)
                              : Qt.rgba(1, 1, 1, area.containsMouse ? 1 : 0.88)
        border.width: 1
        border.color: sistema.escuro ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.9)
    }
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        opacity: circulo.ligado ? 1 : 0
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#7f8ff8" }
            GradientStop { position: 1.0; color: "#5463df" }
        }
        Behavior on opacity { NumberAnimation { duration: 140 } }
    }
    Image {
        anchors.centerIn: parent
        source: pastaIcones + circulo.nome + "-" + (circulo.ligado || sistema.escuro ? "branco" : "escuro") + ".svg"
        sourceSize.width: Math.round(circulo.tamanho * 0.45)
        sourceSize.height: Math.round(circulo.tamanho * 0.45)
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: circulo.clicado()
    }
    ToolTip.visible: circulo.dica !== "" && area.containsMouse
    ToolTip.text: circulo.dica
    ToolTip.delay: 500
}
