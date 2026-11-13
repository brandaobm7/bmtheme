// Sombra leve em volta da busca, como a de uma janela.
// O Plasma só sabe pôr sombra em todos os popups de uma vez, pelo tema. Para ela
// ficar só na busca, esta janela transparente fica no mesmo lugar, um pouco
// maior, e desenha apenas a faixa de fora: anéis de 1 px que vão sumindo.
// O meio fica vazio, e os cliques passam direto por ela.
import QtQuick
import QtQuick.Window
import org.kde.layershell as LayerShell

Window {
    id: sombra

    required property var alvo              // a janela da busca
    readonly property int alcance: 30       // até onde a sombra vai, em px
    readonly property int raio: 24          // o canto dos popups (RAIO_POPUP em ferramentas/gerar-estilo.py)
    readonly property color cor: paleta.escuro ? "#05041a" : "#292159"
    readonly property real forca: paleta.escuro ? 0.62 : 0.30

    // Quanto da força sobra a cada distância da borda (0 = encostado, 1 = no fim).
    function queda(t) {
        const pontos = [[0, 1.0], [0.3, 0.58], [0.65, 0.2], [1, 0.0]]
        for (let i = 1; i < pontos.length; i++) {
            if (t <= pontos[i][0]) {
                const a = pontos[i - 1], b = pontos[i]
                return a[1] + (b[1] - a[1]) * (t - a[0]) / (b[0] - a[0])
            }
        }
        return 0
    }

    Paleta { id: paleta }

    transientParent: null
    visible: alvo.visible
    width: alvo.width + 2 * alcance
    height: alvo.height + 2 * alcance
    color: "transparent"
    flags: Qt.FramelessWindowHint | Qt.WindowTransparentForInput | Qt.WindowDoesNotAcceptFocus

    LayerShell.Window.scope: "bmos-busca-sombra"
    LayerShell.Window.layer: LayerShell.Window.LayerOverlay
    LayerShell.Window.anchors: LayerShell.Window.AnchorTop
    LayerShell.Window.exclusionZone: -1
    // A mesma posição da busca (Busca.qml), menos o alcance da sombra.
    LayerShell.Window.margins.top: Math.round(Screen.height * 0.2) - alcance
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone

    Repeater {
        model: sombra.alcance
        Rectangle {
            required property int index
            anchors.fill: parent
            anchors.margins: sombra.alcance - index - 1
            radius: sombra.raio + index + 1
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(sombra.cor.r, sombra.cor.g, sombra.cor.b,
                                  sombra.forca * sombra.queda((index + 0.5) / sombra.alcance))
        }
    }
}
