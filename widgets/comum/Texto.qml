// Texto padrão do bmos: Inter, na cor do tema.
import QtQuick

Text {
    Paleta { id: paleta }
    font.family: "Inter"
    font.pixelSize: 14
    color: paleta.texto
    elide: Text.ElideRight
}
