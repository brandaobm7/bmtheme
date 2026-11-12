// Data e hora da barra superior, no formato "Qua 11 de nov  22:44".
import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore

PlasmoidItem {
    id: raiz

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    property string texto: ""

    function atualizar() {
        const agora = new Date()
        const local = Qt.locale()
        const formato = local.name.startsWith("pt") ? "ddd d 'de' MMM" : "ddd d MMM"
        // Os nomes abreviados vêm com ponto em alguns idiomas ("qua.", "nov.").
        let data = local.toString(agora, formato).replace(/\./g, "")
        data = data.charAt(0).toUpperCase() + data.slice(1)
        texto = data + "  " + Qt.formatTime(agora, "HH:mm")
    }

    Component.onCompleted: atualizar()

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: raiz.atualizar()
    }

    fullRepresentation: Capsula {
        Text {
            text: raiz.texto
            color: parent.parent.corTexto
            font.family: "Inter"
            font.pixelSize: 13
            font.weight: Font.Medium
        }
    }
}
