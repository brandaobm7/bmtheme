// Botão redondo com ícone: azul-violeta quando ligado, claro quando desligado.
import QtQuick
import org.kde.plasma.core as PlasmaCore

Item {
    id: circulo

    property string nome: ""
    property bool ligado: false
    property int tamanho: 44
    property string dica: ""
    signal clicado()

    implicitWidth: tamanho
    implicitHeight: tamanho

    Paleta { id: paleta }

    // Sombra curta embaixo, que dá o relevo do botão.
    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 2
        anchors.bottomMargin: -2
        radius: width / 2
        color: circulo.ligado ? Qt.rgba(0.23, 0.2, 0.45, 0.16) : paleta.botaoSombra
    }
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: area.containsMouse ? paleta.botaoSobre : paleta.botao
        border.width: 1
        border.color: paleta.botaoBorda
    }
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        opacity: circulo.ligado ? 1 : 0
        gradient: Gradient {
            GradientStop { position: 0.0; color: paleta.destaqueClaro }
            GradientStop { position: 1.0; color: paleta.destaqueFundo }
        }
        Behavior on opacity { NumberAnimation { duration: 140 } }
    }
    Icone {
        anchors.centerIn: parent
        nome: circulo.nome
        tamanho: Math.round(circulo.tamanho * 0.45)
        color: circulo.ligado ? "#ffffff" : paleta.texto
    }
    PlasmaCore.ToolTipArea {
        anchors.fill: parent
        active: circulo.dica !== ""
        mainText: circulo.dica
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: circulo.clicado()
        }
    }
}
