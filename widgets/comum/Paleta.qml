// Cores do bmos para os widgets, no modo claro e no escuro.
// O esquema de cores do Plasma diz qual dos dois está em uso.
import QtQuick
import org.kde.kirigami as Kirigami

QtObject {
    readonly property bool escuro: Kirigami.ColorUtils.brightnessForColor(Kirigami.Theme.backgroundColor) === Kirigami.ColorUtils.Dark

    readonly property color texto: escuro ? "#f2f0fa" : "#1f1d2b"
    readonly property color textoFraco: escuro ? "#a9a5c4" : "#6b6880"

    readonly property color cartao: escuro ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.45)
    readonly property color cartaoBorda: escuro ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.85)
    readonly property color cartaoAtivo: escuro ? Qt.rgba(0.50, 0.56, 0.97, 0.24) : Qt.rgba(0.49, 0.45, 0.92, 0.16)
    readonly property color realce: escuro ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.65)

    readonly property color botao: escuro ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.88)
    readonly property color botaoSobre: escuro ? Qt.rgba(1, 1, 1, 0.20) : Qt.rgba(1, 1, 1, 1)
    readonly property color botaoBorda: escuro ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.9)
    readonly property color botaoSombra: escuro ? Qt.rgba(0, 0, 0, 0.18) : Qt.rgba(0.23, 0.2, 0.45, 0.07)

    readonly property color campo: escuro ? Qt.rgba(1, 1, 1, 0.10) : "#ffffff"
    readonly property color trilho: escuro ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0.43, 0.41, 0.63, 0.18)

    readonly property color destaque: "#5f6ce5"
    readonly property color destaqueSobre: "#6b77ec"
    readonly property color destaqueClaro: "#7f8ff8"
    readonly property color destaqueFundo: "#5463df"
}
