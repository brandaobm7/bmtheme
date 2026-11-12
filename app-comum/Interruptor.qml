// Interruptor no estilo do Mac, azul-violeta quando ligado.
import QtQuick
import QtQuick.Controls

Switch {
    id: chave
    padding: 0
    implicitWidth: 42
    implicitHeight: 24

    indicator: Rectangle {
        width: 42
        height: 24
        radius: 12
        color: chave.checked ? "#5f6ce5" : (sistema.escuro ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0.43, 0.41, 0.63, 0.28))
        Behavior on color { ColorAnimation { duration: 140 } }
        Rectangle {
            width: 20
            height: 20
            radius: 10
            y: 2
            x: chave.checked ? parent.width - width - 2 : 2
            color: "#ffffff"
            Behavior on x { NumberAnimation { duration: 140 } }
        }
    }
    contentItem: Item { }
}
