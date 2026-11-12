// Grade "Todos os apps" do bmos, como o Launchpad do Mac: vidro em tela cheia,
// busca no topo e os apps em grade. Ocupa a área entre a barra e a dock.
import QtQuick
import QtQuick.Window
import QtQuick.Templates as T
import org.kde.plasma.core as PlasmaCore
import org.kde.layershell as LayerShell
import org.kde.kirigami as Kirigami

PlasmaCore.Window {
    id: janela

    property var apps: []
    property double fechadaEm: 0    // hora em que a grade foi fechada pela última vez
    signal aberta()
    signal escolhido(string caminho)

    readonly property var filtrados: {
        const termo = campo.text.trim().toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "")
        return termo === "" ? apps : apps.filter((app) => app.termos.indexOf(termo) >= 0)
    }

    function alternar() {
        if (visible) {
            esconder()
            return
        }
        aberta()
        campo.text = ""
        grade.currentIndex = 0
        grade.positionViewAtBeginning()
        conteudo.opacity = 0
        conteudo.scale = 1.04
        visible = true
        requestActivate()
        campo.forceActiveFocus()
        entrada.restart()
    }
    function esconder() {
        visible = false
        fechadaEm = Date.now()
    }
    // Pedido de fora, pelo ícone da dock. Com a grade aberta, o próprio clique na
    // dock já a fecha, por tirar o foco dela: aí o pedido não a abre de novo.
    function pedir() {
        if (visible || Date.now() - fechadaEm > 700)
            alternar()
    }
    function abrir(app) {
        if (!app)
            return
        escolhido(app.caminho)
        esconder()
    }

    visible: false
    width: Screen.width
    height: Screen.height

    LayerShell.Window.scope: "bmos-apps"
    LayerShell.Window.layer: LayerShell.Window.LayerTop
    LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom
                               | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
    // A janela vai de ponta a ponta da tela, sem passar dela: a parte de fora da
    // tela entraria no desfoque como uma sombra escura nas laterais.
    // Embaixo, para antes da dock, que flutua um pouco acima da área que reserva.
    LayerShell.Window.margins.bottom: 8
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityOnDemand

    // Clicar em outra janela ou na barra fecha a grade.
    onActiveChanged: if (!active && visible) fechar.restart()
    Timer { id: fechar; interval: 150; onTriggered: if (!janela.active) janela.esconder() }

    ParallelAnimation {
        id: entrada
        NumberAnimation { target: conteudo; property: "opacity"; to: 1; duration: 160; easing.type: Easing.OutCubic }
        NumberAnimation { target: conteudo; property: "scale"; to: 1; duration: 200; easing.type: Easing.OutCubic }
    }

    mainItem: Item {
        Paleta { id: paleta }

        // Clicar no vazio fecha.
        MouseArea { anchors.fill: parent; onClicked: janela.esconder() }

        Item {
            id: conteudo
            anchors.fill: parent

            // Campo de busca em pílula de vidro.
            Rectangle {
                id: pilula
                anchors.horizontalCenter: parent.horizontalCenter
                y: 42
                width: 320
                height: 38
                radius: 19
                color: paleta.escuro ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.55)
                border.width: 1
                border.color: paleta.escuro ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.9)

                Icone {
                    x: 14
                    anchors.verticalCenter: parent.verticalCenter
                    nome: "search"
                    tamanho: 16
                    color: paleta.textoFraco
                }
                T.TextField {
                    id: campo
                    anchors.fill: parent
                    leftPadding: 38
                    rightPadding: 14
                    font.family: "Inter"
                    font.pixelSize: 15
                    color: paleta.texto
                    selectionColor: paleta.destaque
                    selectedTextColor: "#ffffff"
                    verticalAlignment: TextInput.AlignVCenter
                    selectByMouse: true
                    onTextChanged: grade.currentIndex = 0
                    onAccepted: janela.abrir(janela.filtrados[grade.currentIndex])
                    Keys.onEscapePressed: text !== "" ? text = "" : janela.esconder()
                    Keys.onDownPressed: grade.moveCurrentIndexDown()
                    Keys.onUpPressed: grade.moveCurrentIndexUp()
                    Keys.onLeftPressed: (evento) => {
                        // Com texto no campo, as setas dos lados movem o cursor do texto.
                        if (text === "")
                            grade.moveCurrentIndexLeft()
                        else
                            evento.accepted = false
                    }
                    Keys.onRightPressed: (evento) => {
                        if (text === "")
                            grade.moveCurrentIndexRight()
                        else
                            evento.accepted = false
                    }
                    Texto {
                        visible: campo.text.length === 0
                        x: 38
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Buscar"
                        font.pixelSize: 15
                        color: paleta.textoFraco
                    }
                }
            }

            GridView {
                id: grade
                readonly property int colunas: Math.max(4, Math.min(7, Math.floor((conteudo.width - 160) / 150)))
                // O realce do teclado só aparece depois da primeira seta.
                property bool teclado: false
                anchors.top: pilula.bottom
                anchors.topMargin: 48
                anchors.horizontalCenter: parent.horizontalCenter
                width: colunas * 150
                // Altura em linhas inteiras, para a última linha não aparecer cortada.
                height: Math.max(1, Math.floor((conteudo.height - y - 16) / cellHeight)) * cellHeight
                cellWidth: 150
                cellHeight: 138
                clip: true
                model: janela.filtrados
                boundsBehavior: Flickable.StopAtBounds
                onCurrentIndexChanged: teclado = currentIndex > 0 || teclado
                onVisibleChanged: teclado = false

                delegate: Item {
                    id: item
                    required property var modelData
                    required property int index
                    width: 150
                    height: 138

                    Rectangle {
                        anchors.centerIn: icone
                        width: 96
                        height: 96
                        radius: 22
                        color: paleta.realce
                        opacity: area.containsMouse || (grade.teclado && grade.currentIndex === item.index) ? 0.7 : 0
                    }
                    Kirigami.Icon {
                        id: icone
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 10
                        width: 72
                        height: 72
                        source: item.modelData.icone
                        scale: area.pressed ? 0.92 : 1
                        Behavior on scale { NumberAnimation { duration: 90 } }
                    }
                    Texto {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: icone.bottom
                        anchors.topMargin: 12
                        width: 132
                        horizontalAlignment: Text.AlignHCenter
                        text: item.modelData.nome
                        font.pixelSize: 13
                        font.weight: Font.Medium
                    }
                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: janela.abrir(item.modelData)
                    }
                }
            }

            Texto {
                visible: janela.filtrados.length === 0
                anchors.centerIn: parent
                text: janela.apps.length === 0 ? "Carregando apps…" : "Nenhum app encontrado"
                color: paleta.textoFraco
                font.pixelSize: 15
            }
        }
    }
}
