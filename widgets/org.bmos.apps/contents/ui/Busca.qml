// Busca do bmos (Alt+Espaço), como o Spotlight do Mac: barra de vidro no alto
// da tela, com os resultados enquanto você digita. Setas escolhem, Enter abre.
// Os resultados vêm do mesmo motor da busca do Plasma: apps, arquivos, contas,
// configurações e o que mais estiver ligado nas Configurações do Sistema.
import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Templates as T
import org.kde.plasma.core as PlasmaCore
import org.kde.layershell as LayerShell
import org.kde.kirigami as Kirigami
import org.kde.milou as Milou

PlasmaCore.Window {
    id: janela

    function alternar() {
        if (visible) {
            esconder()
            return
        }
        campo.text = ""
        visible = true
        requestActivate()
        campo.forceActiveFocus()
    }
    function esconder() { visible = false }
    function abrirEscolhido() {
        if (lista.count > 0 && resultados.run(resultados.index(lista.currentIndex, 0)))
            esconder()
    }

    visible: false
    width: 680
    height: conteudo.implicitHeight + topPadding + bottomPadding

    LayerShell.Window.scope: "bmos-busca"
    LayerShell.Window.layer: LayerShell.Window.LayerOverlay
    LayerShell.Window.anchors: LayerShell.Window.AnchorTop
    LayerShell.Window.exclusionZone: -1
    LayerShell.Window.margins.top: Math.round(Screen.height * 0.2)
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityOnDemand

    // Clicar fora fecha.
    onActiveChanged: if (!active && visible) fechar.restart()
    Timer { id: fechar; interval: 150; onTriggered: if (!janela.active) janela.esconder() }

    Milou.ResultsModel {
        id: resultados
        queryString: janela.visible ? campo.text : ""
        limit: 8
        onModelReset: lista.currentIndex = 0
        onRowsInserted: lista.currentIndex = 0
    }

    mainItem: Item {
        Paleta { id: paleta }

        ColumnLayout {
            id: conteudo
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                spacing: 14
                Icone { nome: "search"; tamanho: 22; color: paleta.textoFraco }
                T.TextField {
                    id: campo
                    Layout.fillWidth: true
                    implicitHeight: 44
                    font.family: "Inter"
                    font.pixelSize: 21
                    color: paleta.texto
                    selectionColor: paleta.destaque
                    selectedTextColor: "#ffffff"
                    verticalAlignment: TextInput.AlignVCenter
                    selectByMouse: true
                    onAccepted: janela.abrirEscolhido()
                    Keys.onDownPressed: lista.incrementCurrentIndex()
                    Keys.onUpPressed: lista.decrementCurrentIndex()
                    Keys.onEscapePressed: text !== "" ? text = "" : janela.esconder()
                    Texto {
                        visible: campo.text.length === 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Buscar apps e arquivos"
                        font.pixelSize: 21
                        color: paleta.textoFraco
                    }
                }
            }

            Rectangle {
                visible: lista.count > 0
                Layout.fillWidth: true
                Layout.topMargin: 8
                implicitHeight: 1
                color: paleta.trilho
            }

            ListView {
                id: lista
                visible: count > 0
                Layout.fillWidth: true
                Layout.topMargin: 6
                implicitHeight: contentHeight
                interactive: false
                model: resultados
                keyNavigationWraps: true
                highlightMoveDuration: 0

                section.property: "category"
                section.delegate: Item {
                    required property string section
                    width: ListView.view.width
                    height: 26
                    Texto {
                        x: 12
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 4
                        text: parent.section
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        color: paleta.textoFraco
                    }
                }

                delegate: Rectangle {
                    id: linha
                    required property var model
                    required property int index
                    readonly property bool escolhida: ListView.isCurrentItem
                    width: ListView.view.width
                    height: 46
                    radius: 12
                    color: escolhida ? "#6a77ee" : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 12
                        Kirigami.Icon {
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            source: linha.model.decoration
                        }
                        Texto {
                            Layout.fillWidth: true
                            text: linha.model.display
                            font.pixelSize: 15
                            color: linha.escolhida ? "#ffffff" : paleta.texto
                        }
                        Texto {
                            Layout.maximumWidth: 260
                            text: linha.model.subtext || ""
                            font.pixelSize: 12
                            color: linha.escolhida ? Qt.rgba(1, 1, 1, 0.8) : paleta.textoFraco
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPositionChanged: lista.currentIndex = linha.index
                        onClicked: {
                            lista.currentIndex = linha.index
                            janela.abrirEscolhido()
                        }
                    }
                }
            }
        }
    }
}
