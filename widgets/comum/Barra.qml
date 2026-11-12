// Controle deslizante com ícone, trilho arredondado e bolinha branca.
import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T

RowLayout {
    id: barra

    property string nome: ""
    property int valor: 0
    readonly property bool arrastando: deslizante.pressed
    signal mudou(int valor)
    signal iconeClicado()

    spacing: 12

    Paleta { id: paleta }

    Icone {
        visible: barra.nome !== ""
        nome: barra.nome
        tamanho: 18
        MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            onClicked: barra.iconeClicado()
        }
    }
    T.Slider {
        id: deslizante
        Layout.fillWidth: true
        implicitWidth: 120
        implicitHeight: 24
        from: 0
        to: 100
        stepSize: 1
        wheelEnabled: true
        onMoved: barra.mudou(Math.round(value))

        // Enquanto a pessoa arrasta, o valor que vem do sistema não puxa a bolinha de volta.
        Binding {
            target: deslizante
            property: "value"
            value: barra.valor
            when: !deslizante.pressed
            restoreMode: Binding.RestoreNone
        }

        background: Rectangle {
            y: (deslizante.height - height) / 2
            width: deslizante.width
            height: 6
            radius: 3
            color: paleta.trilho
            Rectangle {
                width: 12 + deslizante.visualPosition * (parent.width - 24)
                height: parent.height
                radius: 3
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: paleta.destaqueFundo }
                    GradientStop { position: 1.0; color: paleta.destaqueClaro }
                }
            }
        }
        handle: Rectangle {
            x: deslizante.visualPosition * (deslizante.width - width)
            y: (deslizante.height - height) / 2
            width: 24
            height: 24
            radius: 12
            color: "#ffffff"
            border.width: 1
            border.color: Qt.rgba(0.43, 0.41, 0.63, 0.18)
        }
    }
}
