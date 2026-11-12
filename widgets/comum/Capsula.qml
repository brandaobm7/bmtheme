// Cápsula de vidro da barra superior do bmos. Cada widget da barra usa uma,
// com o próprio conteúdo dentro. A barra em si é transparente.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: capsula

    default property alias conteudo: linha.data
    property bool clicavel: false
    property bool vazia: false
    signal pressionado()
    signal clicado()

    // O esquema de cores do Plasma diz se o tema é o claro ou o escuro.
    readonly property bool escuro: Kirigami.ColorUtils.brightnessForColor(Kirigami.Theme.backgroundColor) === Kirigami.ColorUtils.Dark
    readonly property color corTexto: escuro ? "#f2f0fa" : "#1f1d2b"
    readonly property int recuo: 11

    Layout.fillHeight: true
    Layout.minimumWidth: vazia ? 0 : linha.implicitWidth + recuo * 2
    Layout.preferredWidth: Layout.minimumWidth
    Layout.maximumWidth: Layout.minimumWidth
    visible: !vazia

    Rectangle {
        anchors.centerIn: parent
        width: parent.width
        height: Math.min(28, parent.height)
        radius: 13
        color: capsula.escuro
            ? Qt.rgba(0.118, 0.110, 0.212, area.containsMouse ? 0.70 : 0.45)
            : Qt.rgba(1, 1, 1, area.containsMouse ? 0.75 : 0.45)
        border.width: 1
        border.color: capsula.escuro
            ? Qt.rgba(1, 1, 1, area.containsMouse ? 0.25 : 0.16)
            : Qt.rgba(1, 1, 1, area.containsMouse ? 0.92 : 0.78)
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    RowLayout {
        id: linha
        anchors.centerIn: parent
        spacing: 6
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: capsula.clicavel
        enabled: capsula.clicavel
        cursorShape: capsula.clicavel ? Qt.PointingHandCursor : Qt.ArrowCursor
        onPressed: capsula.pressionado()
        onClicked: capsula.clicado()
    }
}
