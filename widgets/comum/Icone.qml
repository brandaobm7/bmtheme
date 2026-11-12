// Ícone Tabler do pacote do widget, pintado na cor pedida.
// O desenho vem direto do arquivo. O Kirigami.Icon não serve aqui: quando o tema
// de ícones do sistema tem um ícone de mesmo nome ("bluetooth", "settings"),
// ele mostra o do tema no lugar do arquivo.
import QtQuick
import QtQuick.Effects
import QtQuick.Window

Item {
    id: icone

    property string nome: ""
    property int tamanho: 18
    property color color: paleta.texto

    Paleta { id: paleta }

    implicitWidth: tamanho
    implicitHeight: tamanho

    Image {
        id: desenho
        anchors.fill: parent
        visible: false
        source: icone.nome !== "" ? Qt.resolvedUrl("../icons/" + icone.nome + ".svg") : ""
        sourceSize.width: Math.round(icone.tamanho * Screen.devicePixelRatio)
        sourceSize.height: Math.round(icone.tamanho * Screen.devicePixelRatio)
    }
    // Os arquivos têm o traço branco: a pintura multiplica a cor pedida pelo
    // brilho do desenho, e com o branco a cor sai exatamente como foi pedida.
    MultiEffect {
        anchors.fill: parent
        source: desenho
        colorization: 1
        colorizationColor: icone.color
    }
}
