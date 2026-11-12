// Central de Controle do bmos: botão na barra superior que abre um painel de vidro
// com Wi-Fi, Bluetooth, som, brilho, perfil de energia, atalhos e bateria.
// O estado e as ações vêm do ajudante em ../code/central.py.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support

PlasmoidItem {
    id: raiz

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    toolTipMainText: "Central de Controle"

    // Estado do sistema, no formato que o ajudante devolve.
    property var e: ({
        wifiDisponivel: false, wifiLigado: false, wifiRede: "",
        btDisponivel: false, btLigado: false,
        somDisponivel: false, volume: 0, mudo: false,
        brilhoDisponivel: false, brilho: 0,
        bateria: -1, carregando: false,
        perfilDisponivel: false, perfil: "alto", perfis: [],
        tema: "claro", luzDisponivel: false, luzNoturna: false
    })
    property string pagina: "principal"
    property int pedido: 0          // número do último comando enviado
    property int acoes: 0           // ações ainda sem resposta
    property var espera: ({})       // valores de volume e brilho à espera de envio

    readonly property string ajudante: "python3 '" + Qt.resolvedUrl("../code/central.py").toString().replace(/^file:\/\//, "") + "'"
    readonly property var perfis: [
        { id: "alto", nome: "Alto", icone: "gauge", texto: "Equilibrado, rápido para o dia a dia." },
        { id: "economico", nome: "Econômico", icone: "leaf", texto: "Gasta menos bateria e esquenta menos." },
        { id: "game", nome: "Game", icone: "device-gamepad-2", texto: "Desempenho máximo para jogar. Gasta mais energia." }
    ]

    function dadosPerfil(id) {
        for (var i = 0; i < perfis.length; i++)
            if (perfis[i].id === id)
                return perfis[i]
        return perfis[0]
    }

    // Cada comando leva um número no fim. Só a resposta do mais recente vale,
    // para uma leitura antiga não desfazer o que a pessoa acabou de mudar.
    function enviar(argumentos) {
        pedido += 1
        comando.connectSource(ajudante + " " + argumentos + " # " + pedido)
    }
    function ler() {
        if (acoes === 0)
            enviar("estado")
    }
    // Muda o valor na tela na hora e manda a ação para o sistema.
    function agir(chave, valor, argumentos) {
        var copia = Object.assign({}, e)
        copia[chave] = valor
        e = copia
        acoes += 1
        enviar(argumentos)
    }
    // Volume e brilho: ao arrastar, envia no máximo um comando a cada 80 ms.
    function deslizar(chave, valor) {
        var copia = Object.assign({}, e)
        copia[chave] = valor
        if (chave === "volume")
            copia.mudo = false
        e = copia
        var fila = Object.assign({}, espera)
        fila[chave] = valor
        espera = fila
        envioLento.start()
    }
    function abrir(programa) {
        expanded = false
        lancador.connectSource(programa + " >/dev/null 2>&1 &")
    }
    // Abre uma página do Ajustes do bmos. Sem o app (o download do PySide6 pode ter
    // falhado na instalação), abre o módulo das Configurações do Sistema no lugar.
    function abrirAjustes(pagina, modulo) {
        abrir("sh -c 'if [ -x \"$HOME/.local/bin/bmos-ajustes\" ]; then exec \"$HOME/.local/bin/bmos-ajustes\" " + pagina
              + "; else exec systemsettings " + modulo + "; fi'")
    }

    P5Support.DataSource {
        id: comando
        engine: "executable"
        onNewData: (origem, dados) => {
            disconnectSource(origem)
            if (origem.indexOf(" estado # ") < 0)
                raiz.acoes = Math.max(0, raiz.acoes - 1)
            if (parseInt(origem.split(" # ").pop()) !== raiz.pedido)
                return
            try {
                raiz.e = JSON.parse(dados.stdout)
            } catch (erro) {
                // Resposta incompleta: fica com o estado anterior até a próxima leitura.
            }
        }
    }
    P5Support.DataSource {
        id: lancador
        engine: "executable"
        onNewData: (origem) => disconnectSource(origem)
    }
    Timer {
        id: envioLento
        interval: 80
        onTriggered: {
            var fila = raiz.espera
            raiz.espera = ({})
            for (var chave in fila) {
                raiz.acoes += 1
                raiz.enviar(chave + " " + fila[chave])
            }
        }
    }
    // Aberta, a Central confere o sistema a cada 2,5 s. Fechada, uma vez por minuto.
    Timer {
        interval: raiz.expanded ? 2500 : 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: raiz.ler()
    }
    onExpandedChanged: (aberta) => {
        if (aberta)
            ler()
        else
            pagina = "principal"
    }

    compactRepresentation: Capsula {
        property bool estavaAberta: false
        clicavel: true
        onPressionado: estavaAberta = raiz.expanded
        onClicado: raiz.expanded = !estavaAberta
        Icone {
            nome: "adjustments-horizontal"
            tamanho: 16
            color: parent.parent.corTexto
        }
    }

    // ---------------- peças só da Central ----------------

    Paleta { id: paleta }

    component Linha: Item {
        id: linha
        property string nome: ""
        property string titulo: ""
        property string situacao: ""
        property bool ligado: false
        signal alternar()
        signal abrirDetalhes()
        implicitWidth: 200
        implicitHeight: 44
        RowLayout {
            anchors.fill: parent
            spacing: 14
            Circulo { nome: linha.nome; ligado: linha.ligado; onClicado: linha.alternar() }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Texto { Layout.fillWidth: true; text: linha.titulo; font.pixelSize: 16; font.weight: Font.Medium }
                Texto { Layout.fillWidth: true; text: linha.situacao; font.pixelSize: 13; color: paleta.textoFraco }
            }
            Icone { nome: "chevron-right"; tamanho: 16; color: paleta.textoFraco }
        }
        MouseArea {
            x: 58
            width: parent.width - 58
            height: parent.height
            cursorShape: Qt.PointingHandCursor
            onClicked: linha.abrirDetalhes()
        }
    }

    component Bateria: RowLayout {
        spacing: 12
        Texto { text: raiz.e.bateria + "%"; font.pixelSize: 13; color: paleta.textoFraco }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 6
            radius: 3
            color: paleta.trilho
            Rectangle {
                width: parent.width * Math.max(0, Math.min(100, raiz.e.bateria)) / 100
                height: parent.height
                radius: 3
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: raiz.e.bateria <= 20 ? "#e0607d" : "#3fb27f" }
                    GradientStop { position: 1.0; color: raiz.e.bateria <= 20 ? "#f19aae" : "#64d39f" }
                }
            }
        }
        Icone { nome: raiz.e.carregando ? "battery-charging" : "battery-2"; tamanho: 22 }
    }

    component Atalho: Item {
        property alias nome: botao.nome
        property alias ligado: botao.ligado
        property alias dica: botao.dica
        signal clicado()
        Layout.fillWidth: true
        implicitHeight: 58
        Circulo { id: botao; anchors.centerIn: parent; tamanho: 56; onClicado: parent.clicado() }
    }

    // ---------------- painel ----------------

    fullRepresentation: Item {
        id: painel

        readonly property int largura: 572
        Layout.minimumWidth: largura
        Layout.preferredWidth: largura
        Layout.maximumWidth: largura
        Layout.minimumHeight: conteudo.implicitHeight
        Layout.preferredHeight: conteudo.implicitHeight
        Layout.maximumHeight: conteudo.implicitHeight

        Keys.onEscapePressed: {
            if (raiz.pagina !== "principal")
                raiz.pagina = "principal"
            else
                raiz.expanded = false
        }

        ColumnLayout {
            id: conteudo
            anchors.fill: parent
            spacing: 0

            // ---------- página principal ----------
            RowLayout {
                visible: raiz.pagina === "principal"
                Layout.fillWidth: true
                spacing: 12

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    Layout.alignment: Qt.AlignTop
                    spacing: 12

                    Cartao {
                        Layout.fillWidth: true
                        implicitHeight: conexoes.implicitHeight + 36
                        ColumnLayout {
                            id: conexoes
                            anchors.fill: parent
                            anchors.margins: 18
                            spacing: 16
                            Linha {
                                Layout.fillWidth: true
                                nome: raiz.e.wifiLigado ? "wifi" : "wifi-off"
                                titulo: "Wi-Fi"
                                situacao: !raiz.e.wifiDisponivel ? "Sem placa Wi-Fi"
                                          : (!raiz.e.wifiLigado ? "Desligado"
                                          : (raiz.e.wifiRede !== "" ? raiz.e.wifiRede : "Não conectado"))
                                ligado: raiz.e.wifiLigado && raiz.e.wifiDisponivel
                                onAlternar: if (raiz.e.wifiDisponivel)
                                                raiz.agir("wifiLigado", !raiz.e.wifiLigado, "wifi " + (raiz.e.wifiLigado ? "desligar" : "ligar"))
                                onAbrirDetalhes: raiz.e.wifiDisponivel ? raiz.pagina = "rede" : raiz.abrirAjustes("wifi", "kcm_networkmanagement")
                            }
                            Linha {
                                visible: raiz.e.btDisponivel
                                Layout.fillWidth: true
                                nome: raiz.e.btLigado ? "bluetooth" : "bluetooth-off"
                                titulo: "Bluetooth"
                                situacao: raiz.e.btLigado ? "Ligado" : "Desligado"
                                ligado: raiz.e.btLigado
                                onAlternar: raiz.agir("btLigado", !raiz.e.btLigado, "bluetooth " + (raiz.e.btLigado ? "desligar" : "ligar"))
                                onAbrirDetalhes: raiz.abrirAjustes("bluetooth", "kcm_bluetooth")
                            }
                        }
                    }

                    Cartao {
                        visible: raiz.e.somDisponivel || raiz.e.brilhoDisponivel
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        implicitHeight: barras.implicitHeight + 36
                        ColumnLayout {
                            id: barras
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: 18
                            spacing: 14
                            Barra {
                                visible: raiz.e.somDisponivel
                                Layout.fillWidth: true
                                nome: raiz.e.mudo ? "volume-off" : "volume"
                                valor: raiz.e.mudo ? 0 : raiz.e.volume
                                onMudou: (v) => raiz.deslizar("volume", v)
                                onIconeClicado: raiz.agir("mudo", !raiz.e.mudo, "mudo")
                            }
                            Barra {
                                visible: raiz.e.brilhoDisponivel
                                Layout.fillWidth: true
                                nome: "brightness-half"
                                valor: raiz.e.brilho
                                onMudou: (v) => raiz.deslizar("brilho", Math.max(1, v))
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    Layout.alignment: Qt.AlignTop
                    spacing: 12

                    Cartao {
                        visible: raiz.e.perfilDisponivel
                        Layout.fillWidth: true
                        implicitHeight: 80
                        Linha {
                            anchors.fill: parent
                            anchors.margins: 18
                            nome: raiz.dadosPerfil(raiz.e.perfil).icone
                            titulo: "Perfil"
                            situacao: raiz.dadosPerfil(raiz.e.perfil).nome
                            onAlternar: raiz.pagina = "perfil"
                            onAbrirDetalhes: raiz.pagina = "perfil"
                        }
                    }

                    Cartao {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        implicitHeight: atalhos.implicitHeight + 36
                        ColumnLayout {
                            id: atalhos
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: 18
                            spacing: 16
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                // Aparência: sol no modo claro, lua no modo escuro.
                                Atalho {
                                    nome: raiz.e.tema === "escuro" ? "moon" : "sun-high"
                                    ligado: raiz.e.tema === "escuro"
                                    dica: raiz.e.tema === "escuro" ? "Modo escuro (clique para o claro)" : "Modo claro (clique para o escuro)"
                                    onClicado: {
                                        var novo = raiz.e.tema === "escuro" ? "claro" : "escuro"
                                        raiz.agir("tema", novo, "tema " + novo)
                                    }
                                }
                                Atalho {
                                    visible: raiz.e.luzDisponivel
                                    nome: "sunset-2"
                                    ligado: raiz.e.luzNoturna
                                    dica: raiz.e.luzNoturna ? "Luz noturna ligada" : "Luz noturna"
                                    onClicado: raiz.agir("luzNoturna", !raiz.e.luzNoturna, "luz " + (raiz.e.luzNoturna ? "desligar" : "ligar"))
                                }
                                Atalho {
                                    nome: "device-desktop"
                                    dica: "Tela"
                                    onClicado: raiz.abrirAjustes("tela", "kcm_kscreen")
                                }
                                Atalho {
                                    nome: "settings"
                                    dica: "Ajustes"
                                    onClicado: raiz.abrirAjustes("", "")
                                }
                            }
                            Rectangle {
                                visible: raiz.e.bateria >= 0
                                Layout.fillWidth: true
                                implicitHeight: 48
                                radius: 24
                                color: paleta.escuro ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.55)
                                Bateria { anchors.fill: parent; anchors.leftMargin: 18; anchors.rightMargin: 16 }
                            }
                        }
                    }
                }
            }

            // ---------- lista de redes Wi-Fi ----------
            ColumnLayout {
                visible: raiz.pagina === "rede"
                Layout.fillWidth: true
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Circulo { tamanho: 34; nome: "chevron-left"; dica: "Voltar"; onClicado: raiz.pagina = "principal" }
                    Texto { Layout.fillWidth: true; text: "Wi-Fi"; font.pixelSize: 18; font.weight: Font.DemiBold }
                    Circulo {
                        visible: redes.status === Loader.Ready
                        tamanho: 34
                        nome: "refresh"
                        dica: "Procurar redes"
                        opacity: redes.item && redes.item.buscando ? 0.5 : 1
                        onClicado: redes.item.buscar()
                    }
                    Circulo {
                        tamanho: 34
                        nome: raiz.e.wifiLigado ? "wifi" : "wifi-off"
                        ligado: raiz.e.wifiLigado
                        dica: raiz.e.wifiLigado ? "Desligar o Wi-Fi" : "Ligar o Wi-Fi"
                        onClicado: raiz.agir("wifiLigado", !raiz.e.wifiLigado, "wifi " + (raiz.e.wifiLigado ? "desligar" : "ligar"))
                    }
                }

                // A lista usa o módulo de rede do Plasma. Só é carregada quando a página abre.
                Loader {
                    id: redes
                    Layout.fillWidth: true
                    active: raiz.pagina === "rede"
                    visible: status === Loader.Ready
                    source: "Redes.qml"
                    onLoaded: item.wifiLigado = Qt.binding(() => raiz.e.wifiLigado)
                }
                // Sem o módulo de rede do Plasma, o caminho é a tela de redes do sistema.
                Cartao {
                    visible: redes.status === Loader.Error
                    Layout.fillWidth: true
                    implicitHeight: 64
                    Texto {
                        anchors.fill: parent
                        anchors.margins: 18
                        verticalAlignment: Text.AlignVCenter
                        text: "Abrir as redes nas Configurações do Sistema"
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: raiz.abrirAjustes("wifi", "kcm_networkmanagement")
                    }
                }
            }

            // ---------- perfis de energia ----------
            ColumnLayout {
                visible: raiz.pagina === "perfil"
                Layout.fillWidth: true
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Circulo { tamanho: 34; nome: "chevron-left"; dica: "Voltar"; onClicado: raiz.pagina = "principal" }
                    Texto { Layout.fillWidth: true; text: "Perfil de desempenho"; font.pixelSize: 18; font.weight: Font.DemiBold }
                }

                Repeater {
                    model: raiz.perfis.filter((p) => raiz.e.perfis.indexOf(p.id) >= 0)
                    delegate: Cartao {
                        id: opcao
                        required property var modelData
                        readonly property bool atual: raiz.e.perfil === modelData.id
                        Layout.fillWidth: true
                        implicitHeight: 72
                        color: atual ? paleta.cartaoAtivo : paleta.cartao

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            spacing: 14
                            Circulo { tamanho: 44; nome: opcao.modelData.icone; ligado: opcao.atual }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Texto { text: opcao.modelData.nome; font.pixelSize: 15; font.weight: Font.DemiBold }
                                Texto { Layout.fillWidth: true; text: opcao.modelData.texto; font.pixelSize: 12; color: paleta.textoFraco }
                            }
                            Icone { visible: opcao.atual; nome: "check"; tamanho: 18 }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: raiz.agir("perfil", opcao.modelData.id, "perfil " + opcao.modelData.id)
                        }
                    }
                }
            }
        }
    }
}
