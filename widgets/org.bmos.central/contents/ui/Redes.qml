// Lista de redes Wi-Fi da Central, com a senha na própria linha.
// Usa o módulo de rede do Plasma: as redes salvas, a senha e a conexão passam
// pelo NetworkManager, como no widget de rede do próprio Plasma.
import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T
import org.kde.plasma.networkmanagement as PlasmaNM

Cartao {
    id: cartao

    property bool wifiLigado: true
    property int alturaMaxima: 264
    readonly property bool buscando: handler.scanning

    function buscar() { handler.requestScan() }
    function iconeWifi(sinal) { return sinal >= 67 ? "wifi" : (sinal >= 34 ? "wifi-2" : "wifi-1") }

    implicitHeight: lista.contentHeight > 0 && wifiLigado ? Math.min(lista.contentHeight + 16, alturaMaxima) : 72

    Paleta { id: paleta }
    PlasmaNM.Handler { id: handler }
    PlasmaNM.NetworkModel { id: todas }
    PlasmaNM.AppletProxyModel { id: disponiveis; sourceModel: todas }

    Timer {
        interval: 10200
        running: cartao.visible && cartao.wifiLigado
        repeat: true
        triggeredOnStart: true
        onTriggered: handler.requestScan()
    }

    Texto {
        visible: lista.contentHeight === 0 || !cartao.wifiLigado
        anchors.centerIn: parent
        color: paleta.textoFraco
        font.pixelSize: 13
        text: !cartao.wifiLigado ? "O Wi-Fi está desligado"
              : (cartao.buscando ? "Procurando redes…" : "Nenhuma rede encontrada")
    }

    ListView {
        id: lista
        anchors.fill: parent
        anchors.margins: 8
        visible: cartao.wifiLigado
        clip: true
        model: disponiveis
        boundsBehavior: Flickable.StopAtBounds
        property string escolhida: ""

        delegate: Item {
            id: rede
            required property var model

            // O modelo também traz cabo e VPN. Aqui só entram as redes sem fio.
            readonly property bool semFio: model.Type === PlasmaNM.Enums.Wireless
            readonly property bool conectada: model.ConnectionState === PlasmaNM.Enums.Activated
            readonly property bool conectando: model.ConnectionState === PlasmaNM.Enums.Activating
            readonly property bool conhecida: model.Uuid !== undefined && model.Uuid !== ""
            readonly property bool segura: model.SecurityType !== PlasmaNM.Enums.NoneSecurity
                                           && model.SecurityType !== PlasmaNM.Enums.UnknownSecurity
            // Redes de casa pedem só uma senha. As de empresa abrem a tela de conexão do sistema.
            readonly property bool senhaSimples: model.SecurityType === PlasmaNM.Enums.StaticWep
                                                 || model.SecurityType === PlasmaNM.Enums.WpaPsk
                                                 || model.SecurityType === PlasmaNM.Enums.Wpa2Psk
                                                 || model.SecurityType === PlasmaNM.Enums.SAE
            readonly property bool aberta: lista.escolhida === model.ItemUniqueName && !conhecida && senhaSimples && !conectada

            function conectar(senhaDigitada) {
                if (conhecida)
                    handler.activateConnection(model.ConnectionPath, model.DevicePath, model.SpecificPath)
                else if (senhaDigitada !== "")
                    handler.addAndActivateConnection(model.DevicePath, model.SpecificPath, senhaDigitada)
                else
                    handler.addAndActivateConnection(model.DevicePath, model.SpecificPath)
                lista.escolhida = ""
            }

            visible: semFio
            width: ListView.view.width
            height: !semFio ? 0 : (aberta ? 96 : 44)
            Behavior on height { NumberAnimation { duration: 120 } }

            Rectangle {
                anchors.fill: parent
                anchors.topMargin: 1
                anchors.bottomMargin: 1
                radius: 12
                color: rede.aberta || areaRede.containsMouse ? paleta.realce : "transparent"
            }

            RowLayout {
                x: 12
                width: parent.width - 24
                height: 44
                spacing: 12
                Icone { nome: cartao.iconeWifi(rede.model.Signal); tamanho: 18 }
                Texto {
                    Layout.fillWidth: true
                    text: rede.model.ItemUniqueName
                    font.weight: rede.conectada ? Font.DemiBold : Font.Normal
                }
                Texto {
                    visible: rede.conectando
                    text: "Conectando…"
                    font.pixelSize: 12
                    color: paleta.textoFraco
                }
                Icone { visible: rede.segura; nome: "lock"; tamanho: 15; color: paleta.textoFraco }
                Icone { visible: rede.conectada; nome: "check"; tamanho: 16 }
            }

            MouseArea {
                id: areaRede
                width: parent.width
                height: 44
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (rede.conectada || rede.conectando)
                        return
                    if (rede.conhecida || !rede.segura || !rede.senhaSimples) {
                        rede.conectar("")
                    } else {
                        lista.escolhida = rede.model.ItemUniqueName
                        senha.forceActiveFocus()
                    }
                }
            }

            RowLayout {
                visible: rede.aberta
                x: 12
                y: 50
                width: parent.width - 24
                spacing: 8
                T.TextField {
                    id: senha
                    Layout.fillWidth: true
                    implicitHeight: 36
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    font.family: "Inter"
                    font.pixelSize: 14
                    color: paleta.texto
                    selectionColor: paleta.destaque
                    selectedTextColor: "#ffffff"
                    leftPadding: 12
                    rightPadding: 12
                    verticalAlignment: TextInput.AlignVCenter
                    selectByMouse: true
                    onAccepted: if (text.length > 0) rede.conectar(text)
                    background: Rectangle {
                        radius: 10
                        color: paleta.campo
                        border.width: senha.activeFocus ? 1.5 : 1
                        border.color: senha.activeFocus ? "#8b97f6" : paleta.trilho
                    }
                    Texto {
                        visible: senha.text.length === 0
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Senha da rede"
                        color: paleta.textoFraco
                    }
                }
                Botao {
                    text: "Conectar"
                    enabled: senha.text.length > 0
                    onClicked: rede.conectar(senha.text)
                }
            }
        }
    }
}
