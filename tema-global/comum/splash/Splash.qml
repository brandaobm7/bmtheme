// Tela de abertura do bmos: aparece entre o login e a área de trabalho.
// Papel de parede, o logo e uma barra que enche conforme o Plasma carrega.
// O instalador põe em images/fundo.png um atalho para o papel de parede do tema.
import QtQuick

Rectangle {
    id: raiz

    // O Plasma avança esta etapa de 1 a 6 enquanto carrega.
    property int stage
    // A barra começa com um pouco de cor, para não parecer parada.
    readonly property real progresso: Math.max(0.08, Math.min(1, stage / 6))

    // O desenho foi feito para uma tela de 800 px de altura. Em telas maiores,
    // o logo e a barra crescem na mesma proporção.
    readonly property real escala: Math.max(1, height / 800)

    color: "#e6e3f5"

    Image {
        anchors.fill: parent
        source: "images/fundo.png"
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: raiz.width
        sourceSize.height: raiz.height
    }

    Image {
        id: logo
        anchors.centerIn: parent
        anchors.verticalCenterOffset: Math.round(-20 * raiz.escala)
        width: Math.round(96 * raiz.escala)
        height: width
        source: "images/logo.svg"
        sourceSize.width: width * 2
        sourceSize.height: height * 2
    }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: logo.bottom
        anchors.topMargin: Math.round(50 * raiz.escala)
        width: Math.round(200 * raiz.escala)
        height: Math.round(6 * raiz.escala)
        radius: height / 2
        color: Qt.rgba(1, 1, 1, 0.6)
        border.width: 1
        border.color: Qt.rgba(0.43, 0.41, 0.63, 0.18)

        Rectangle {
            width: Math.max(height, parent.width * raiz.progresso)
            height: parent.height
            radius: height / 2
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#5463df" }
                GradientStop { position: 1.0; color: "#7f8ff8" }
            }
            Behavior on width { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
        }
    }
}
