// Ajustes do bmos: os ajustes do dia a dia, no visual do tema.
//
// A tela é feita de peças. Cada página é uma lista de grupos, e cada grupo uma
// lista de linhas ("paginas", mais abaixo). Uma linha diz o tipo da peça
// (escolha, segmentos, interruptor, barra, botao, info...), o título e a chave do
// ajuste. Para pôr um ajuste novo basta uma linha nova aqui e, no ajustes.py,
// como ler e gravar a chave dele.
//
// Quem lê e grava é o objeto "ajustes" (ajustes.py), nos mesmos lugares que as
// Configurações do Sistema do Plasma usam. Para o que não está aqui, cada página
// tem um atalho para o módulo correspondente de lá.
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Window
import "../app-comum"

Window {
    id: janela

    readonly property int margem: 56      // faixa em volta, só para a sombra
    readonly property int raio: 24
    readonly property int lateral: 250
    readonly property var v: ajustes.valores
    readonly property var o: ajustes.opcoes
    property string pagina: secoes.some(s => s.id === paginaInicial) ? paginaInicial : "wifi"
    property string mensagem: ""

    // Cores nos modos claro e escuro. O modo acompanha o tema do bmos.
    readonly property bool escuro: sistema.escuro
    readonly property color corTexto: escuro ? "#f2f0fa" : "#1f1d2b"
    readonly property color corTextoMedio: escuro ? "#aaa6c6" : "#6b6880"
    readonly property color corTextoFraco: escuro ? "#8d89aa" : "#8f8ca3"
    readonly property color corCartao: escuro ? "#2a2745" : "#ffffff"
    readonly property color corCampo: escuro ? "#35325a" : "#ffffff"
    readonly property color corConteudo: escuro ? "#1e1c36" : "#fbfaff"
    readonly property color corLateralCima: escuro ? "#2b2849" : "#ecebfa"
    readonly property color corLateralBaixo: escuro ? "#262343" : "#e7e3f4"
    readonly property string iconeForte: escuro ? "-branco.svg" : "-escuro.svg"
    function linha(forca) { return escuro ? Qt.rgba(1, 1, 1, forca * 1.1) : Qt.rgba(0.43, 0.41, 0.63, forca) }
    function brilho(forca) { return escuro ? Qt.rgba(1, 1, 1, forca * 0.13) : Qt.rgba(1, 1, 1, forca) }

    // Páginas, com o módulo das Configurações do Sistema que tem as opções a mais.
    readonly property var secoes: [
        { id: "wifi", nome: "Wi-Fi", icone: "wifi", mais: "kcm_networkmanagement" },
        { id: "bluetooth", nome: "Bluetooth", icone: "bluetooth", mais: "kcm_bluetooth" },
        { id: "tela", nome: "Tela", icone: "device-desktop", mais: "kcm_kscreen" },
        { id: "som", nome: "Som", icone: "volume", mais: "kcm_pulseaudio" },
        { id: "aparencia", nome: "Aparência", icone: "palette", mais: "kcm_lookandfeel" },
        { id: "perfis", nome: "Perfis", icone: "gauge", mais: "kcm_powerdevilprofilesconfig" },
        { id: "atualizacoes", nome: "Atualizações", icone: "cloud-download", mais: "" },
        { id: "hardware", nome: "Hardware", icone: "cpu", mais: "kcm_about-distro" },
        { id: "data", nome: "Data e hora", icone: "clock", mais: "kcm_clock" },
        { id: "sobre", nome: "Sobre o bmos", icone: "info-circle", mais: "" }
    ]
    readonly property var secao: secoes.find(s => s.id === pagina)

    // O conteúdo de cada página. "se" é a chave que precisa ser verdadeira para o
    // grupo ou a linha aparecer: é assim que some o que o computador não tem.
    readonly property var paginas: ({
        wifi: [
            { se: "wifi.tem", linhas: [
                { tipo: "interruptor", chave: "wifi.ligado", titulo: "Wi-Fi", texto: "Procura e conecta em redes sem fio." } ] },
            { titulo: "Redes", se: "wifi.ligado", linhas: [ { tipo: "redes" } ] },
            { se: "!wifi.tem", linhas: [
                { tipo: "info", titulo: "Sem placa Wi-Fi", texto: "Este computador não tem rede sem fio. A rede por cabo funciona sozinha." } ] }
        ],
        bluetooth: [
            { se: "bluetooth.tem", linhas: [
                { tipo: "interruptor", chave: "bluetooth.ligado", titulo: "Bluetooth", texto: "Fones, caixas de som, controles e mouses sem fio." } ] },
            { titulo: "Aparelhos", se: "bluetooth.ligado", linhas: [ { tipo: "aparelhos" } ] },
            { se: "!bluetooth.tem", linhas: [
                { tipo: "info", titulo: "Sem Bluetooth", texto: "Este computador não tem Bluetooth." } ] }
        ],
        tela: [
            { titulo: "Monitor", se: "tela.temMonitor", linhas: [
                { tipo: "escolha", chave: "tela.resolucao", titulo: "Resolução", texto: "A maior da lista costuma ser a ideal para a tela." },
                { tipo: "escolha", chave: "tela.taxa", titulo: "Taxa de atualização", texto: "Quanto maior, mais fluido o movimento na tela." },
                { tipo: "segmentos", chave: "tela.escala", titulo: "Tamanho da interface", texto: "125% e 150% aumentam os textos. 200% dobra tudo, para telas 4K." },
                { tipo: "barra", chave: "tela.brilho", se: "tela.temBrilho", titulo: "Brilho", minimo: 1 },
                { tipo: "escolha", chave: "tela.luz", largura: 240, titulo: "Luz noturna", texto: "Deixa a tela mais amarelada, para cansar menos a vista à noite." },
                { tipo: "botao", acao: "mais:kcm_kscreen", rotulo: "Abrir", titulo: "Vários monitores e rotação", texto: "Posição de cada monitor, tela principal e giro da imagem." } ] },
            { titulo: "Descanso", linhas: [
                { tipo: "escolha", chave: "tela.bloquear", titulo: "Bloquear a tela", texto: "Depois deste tempo sem uso, a tela mostra o papel de parede com o relógio." },
                { tipo: "escolha", chave: "tela.apagar", titulo: "Apagar a tela", texto: "Tempo sem uso até a tela desligar." },
                { tipo: "escolha", chave: "tela.suspender", titulo: "Suspender o computador", texto: "Suspenso, ele quase não gasta energia e volta de onde parou." } ] }
        ],
        som: [
            { titulo: "Saída", se: "som.temSaida", linhas: [
                { tipo: "escolha", chave: "som.saida", largura: 260, titulo: "Aparelho", texto: "Por onde o som sai: alto-falantes, fone ou TV." },
                { tipo: "barra", chave: "som.saidaVolume", titulo: "Volume" },
                { tipo: "interruptor", chave: "som.saidaMudo", titulo: "Sem som" } ] },
            { titulo: "Entrada", se: "som.temEntrada", linhas: [
                { tipo: "escolha", chave: "som.entrada", largura: 260, titulo: "Microfone", texto: "De onde a voz é captada." },
                { tipo: "barra", chave: "som.entradaVolume", titulo: "Volume do microfone" },
                { tipo: "interruptor", chave: "som.entradaMudo", titulo: "Microfone desligado" } ] }
        ],
        aparencia: [
            { titulo: "Modo", linhas: [
                { tipo: "segmentos", chave: "aparencia.modo", titulo: "Claro ou escuro", texto: "Muda as janelas, a barra, a dock e os apps de uma vez." } ] },
            { titulo: "Papel de parede", linhas: [ { tipo: "fundos", chave: "aparencia.fundo" } ] }
        ],
        perfis: [
            { titulo: "Desempenho", se: "perfis.tem", linhas: [
                { tipo: "segmentos", chave: "perfis.perfil", titulo: "Perfil", texto: "Econômico gasta menos bateria. Alto é o equilíbrio do dia a dia. Game dá o desempenho máximo." },
                { tipo: "info", chave: "perfis.bateria", se: "perfis.bateria", titulo: "Bateria" } ] },
            { titulo: "Descanso", linhas: [
                { tipo: "botao", acao: "pagina:tela", rotulo: "Abrir", titulo: "Bloqueio, tela e suspensão", texto: "Os tempos de descanso ficam na página Tela." } ] }
        ],
        atualizacoes: [
            { titulo: "Sistema", se: "atualizacoes.tem", linhas: [
                { tipo: "info", chave: "atualizacoes.sistema", titulo: "Versão em uso" },
                { tipo: "botao", acao: "reiniciar", rotulo: "Reiniciar", se: "atualizacoes.pronta", titulo: "Atualização pronta", chaveTexto: "atualizacoes.pronta", texto: "Já foi baixada. Entra em uso ao reiniciar: " },
                { tipo: "botao", acao: "atualizar", rotulo: "Atualizar", titulo: "Procurar atualizações", texto: "Abre um terminal com o atualizador do sistema, que também atualiza os apps." },
                { tipo: "info", chave: "atualizacoes.automaticas", titulo: "Atualização automática", texto: "O sistema baixa as atualizações sozinho e aplica ao reiniciar." } ] },
            { titulo: "Apps", se: "atualizacoes.temFlatpak", linhas: [
                { tipo: "info", chave: "atualizacoes.apps", titulo: "Apps com atualização", texto: "Apps instalados pela loja (Flatpak)." } ] }
        ],
        hardware: [
            { titulo: "Este computador", linhas: [
                { tipo: "info", chave: "hardware.processador", titulo: "Processador" },
                { tipo: "info", chave: "hardware.nucleos", titulo: "Núcleos" },
                { tipo: "info", chave: "hardware.memoria", titulo: "Memória" },
                { tipo: "info", chave: "hardware.video", titulo: "Placa de vídeo" },
                { tipo: "info", chave: "hardware.tela", se: "hardware.tela", titulo: "Tela" },
                { tipo: "info", chave: "hardware.disco", titulo: "Armazenamento" } ] }
        ],
        data: [
            { titulo: "Relógio", linhas: [
                { tipo: "info", chave: "data.agora", titulo: "Agora" },
                { tipo: "interruptor", chave: "data.automatica", titulo: "Acertar pela internet", texto: "Mantém a hora certa sozinho." },
                { tipo: "escolha", chave: "data.fuso", largura: 220, titulo: "Fuso horário", texto: "Os outros fusos ficam nas Configurações do Sistema." } ] }
        ],
        sobre: [
            { titulo: "Versões", linhas: [
                { tipo: "info", chave: "sobre.tema", titulo: "Tema bmos" },
                { tipo: "info", chave: "sobre.sistema", titulo: "Sistema" },
                { tipo: "info", chave: "sobre.plasma", titulo: "KDE Plasma" },
                { tipo: "info", chave: "sobre.kernel", titulo: "Kernel" } ] },
            { titulo: "Mais ajustes", linhas: [
                { tipo: "botao", acao: "mais:", rotulo: "Abrir", titulo: "Configurações do Sistema", texto: "Todas as opções do KDE Plasma, para o que não está aqui." } ] }
        ]
    })

    // "se" de um grupo ou linha: a chave precisa ter valor. Com "!" na frente, precisa
    // não ter, e só depois que a página foi lida: antes disso ainda não se sabe, e a
    // tela não pode dizer que o computador não tem a placa.
    function vale(se) {
        if (se === undefined)
            return true
        const negado = se.charAt(0) === "!"
        const valor = v[negado ? se.slice(1) : se]
        if (valor === undefined)
            return false
        const tem = valor !== false && valor !== ""
        return negado ? !tem : tem
    }
    function mostrar(valor) {
        if (valor === undefined)
            return "…"
        if (valor === true)
            return "Ligada"
        if (valor === false)
            return "Desligada"
        if (typeof valor === "object" && valor.length !== undefined) {
            // Uma lista (as placas de vídeo, por exemplo) sai com um item por linha.
            const partes = []
            for (let i = 0; i < valor.length; i++)
                partes.push(String(valor[i]))
            return partes.join("\n")
        }
        return String(valor)
    }
    function fazer(acao) {
        if (acao.indexOf("mais:") === 0)
            ajustes.maisOpcoes(acao.slice(5))
        else if (acao.indexOf("pagina:") === 0)
            pagina = acao.slice(7)
        else if (acao === "atualizar")
            ajustes.atualizarSistema()
        else if (acao === "reiniciar")
            ajustes.reiniciar()
    }
    function avisar(texto) {
        mensagem = texto
        tempoAviso.restart()
    }

    flags: Qt.FramelessWindowHint | Qt.Window
    color: "transparent"
    title: "Ajustes"
    visible: true
    width: 980 + 2 * margem
    height: 640 + 2 * margem
    minimumWidth: width
    maximumWidth: width
    minimumHeight: height
    maximumHeight: height

    Component.onCompleted: ajustes.atualizar(pagina)
    onPaginaChanged: {
        rolagem.contentY = 0
        ajustes.atualizar(pagina)
    }
    // Com a janela em uso, a página aberta é conferida a cada poucos segundos:
    // o volume, o brilho ou a rede podem mudar por fora do Ajustes.
    Timer {
        interval: 4000
        repeat: true
        running: janela.active && ["wifi", "bluetooth", "tela", "som", "perfis", "data"].indexOf(janela.pagina) >= 0
        onTriggered: ajustes.atualizar(janela.pagina)
    }
    Timer { id: tempoAviso; interval: 3800; onTriggered: janela.mensagem = "" }
    Connections {
        target: ajustes
        function onAviso(texto) { janela.avisar(texto) }
    }
    Shortcut { sequence: "Ctrl+W"; onActivated: Qt.quit() }

    // ---------------- peças ----------------

    // Lista suspensa.
    component Escolha: Rectangle {
        id: escolha
        property var opcoes: []          // [{ id, nome }]
        property string atual: ""
        signal escolhido(string id)
        implicitWidth: 190
        implicitHeight: 34
        radius: 10
        color: janela.escuro ? Qt.rgba(1, 1, 1, areaEscolha.containsMouse || lista.opened ? 0.16 : 0.1)
                             : Qt.rgba(1, 1, 1, areaEscolha.containsMouse || lista.opened ? 1 : 0.8)
        border.width: 1
        border.color: janela.linha(0.2)
        Texto {
            x: 14
            width: parent.width - 44
            anchors.verticalCenter: parent.verticalCenter
            text: {
                const achada = escolha.opcoes.find(op => op.id === escolha.atual)
                return achada ? achada.nome : (escolha.atual === "" ? "…" : escolha.atual)
            }
            font.pixelSize: 13
            font.weight: Font.Medium
        }
        Image {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            source: pastaIcones + "chevron-down-cinza.svg"
            sourceSize.width: 16
            sourceSize.height: 16
        }
        MouseArea {
            id: areaEscolha
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: lista.opened ? lista.close() : lista.open()
        }
        Popup {
            id: lista
            // Perto do fim da janela, a lista abre para cima, para não ficar cortada.
            property bool paraCima: false
            onAboutToShow: paraCima = escolha.mapToItem(null, 0, escolha.height).y + height + 22 > janela.height - janela.margem
            y: paraCima ? -height - 6 : escolha.height + 6
            width: escolha.width
            height: Math.min(itens.contentHeight + 12, 232)
            padding: 6
            background: Rectangle {
                radius: 12
                color: janela.corCampo
                border.width: 1
                border.color: janela.linha(0.18)
            }
            contentItem: ListView {
                id: itens
                clip: true
                model: escolha.opcoes
                boundsBehavior: Flickable.StopAtBounds
                ScrollIndicator.vertical: ScrollIndicator { }
                delegate: Rectangle {
                    id: opcao
                    required property var modelData
                    readonly property bool marcada: modelData.id === escolha.atual
                    width: itens.width
                    height: 30
                    radius: 8
                    color: areaOpcao.containsMouse ? "#5f6ce5" : "transparent"
                    Texto {
                        x: 10
                        width: parent.width - 38
                        anchors.verticalCenter: parent.verticalCenter
                        text: opcao.modelData.nome
                        font.pixelSize: 13
                        color: areaOpcao.containsMouse ? "#ffffff" : janela.corTexto
                    }
                    Image {
                        visible: opcao.marcada
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        source: pastaIcones + "check" + (areaOpcao.containsMouse || janela.escuro ? "-branco.svg" : "-escuro.svg")
                        sourceSize.width: 14
                        sourceSize.height: 14
                    }
                    MouseArea {
                        id: areaOpcao
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            lista.close()
                            if (!opcao.marcada)
                                escolha.escolhido(opcao.modelData.id)
                        }
                    }
                }
            }
        }
    }

    // Escolha entre poucas opções, lado a lado.
    component Segmentos: Rectangle {
        id: segmentos
        property var opcoes: []
        property string atual: ""
        signal escolhido(string id)
        implicitWidth: fileira.implicitWidth + 6
        implicitHeight: 34
        radius: 10
        color: janela.linha(0.12)
        Row {
            id: fileira
            x: 3
            y: 3
            Repeater {
                model: segmentos.opcoes
                delegate: Rectangle {
                    id: parte
                    required property var modelData
                    readonly property bool marcada: modelData.id === segmentos.atual
                    width: Math.max(58, rotulo.implicitWidth + 28)
                    height: 28
                    radius: 8
                    color: marcada ? (janela.escuro ? Qt.rgba(1, 1, 1, 0.2) : "#ffffff") : "transparent"
                    Texto {
                        id: rotulo
                        anchors.centerIn: parent
                        text: parte.modelData.nome
                        font.pixelSize: 13
                        font.weight: parte.marcada ? Font.DemiBold : Font.Medium
                        color: parte.marcada ? janela.corTexto : janela.corTextoMedio
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (!parte.marcada) segmentos.escolhido(parte.modelData.id)
                    }
                }
            }
        }
    }

    // Controle deslizante, com o valor ao lado.
    component Deslizante: RowLayout {
        id: deslizante
        property int valor: 0
        property int minimo: 0
        signal mudou(int valor)
        width: 260
        spacing: 10
        Slider {
            id: trilho
            Layout.fillWidth: true
            implicitHeight: 24
            from: deslizante.minimo
            to: 100
            stepSize: 1
            // O valor escolhido fica guardado à parte: ao soltar, a bolinha volta por um
            // instante ao valor do sistema, e é o guardado que vale.
            property int escolhido: 0
            onMoved: {
                escolhido = Math.round(value)
                envio.restart()
            }
            onPressedChanged: {
                if (!pressed && envio.running) {
                    envio.stop()
                    deslizante.mudou(escolhido)
                }
            }
            // Enquanto a pessoa arrasta, o valor que vem do sistema não puxa a bolinha de volta.
            Binding { target: trilho; property: "value"; value: deslizante.valor; when: !trilho.pressed; restoreMode: Binding.RestoreNone }
            // Ao arrastar, grava no máximo uma vez a cada 80 ms.
            Timer { id: envio; interval: 80; onTriggered: deslizante.mudou(trilho.escolhido) }
            background: Rectangle {
                y: (trilho.height - height) / 2
                width: trilho.width
                height: 6
                radius: 3
                color: janela.linha(0.18)
                Rectangle {
                    width: 10 + trilho.visualPosition * (parent.width - 20)
                    height: parent.height
                    radius: 3
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "#5463df" }
                        GradientStop { position: 1.0; color: "#7f8ff8" }
                    }
                }
            }
            handle: Rectangle {
                x: trilho.visualPosition * (trilho.width - width)
                y: (trilho.height - height) / 2
                width: 20
                height: 20
                radius: 10
                color: "#ffffff"
                border.width: 1
                border.color: Qt.rgba(0.43, 0.41, 0.63, 0.25)
            }
        }
        Texto {
            Layout.preferredWidth: 38
            horizontalAlignment: Text.AlignRight
            text: Math.round(trilho.value) + "%"
            font.pixelSize: 13
            color: janela.corTextoMedio
        }
    }

    // Redes sem fio, com a senha na própria linha.
    component Redes: Column {
        id: redes
        property string escolhida: ""
        function sinal(forca) { return forca >= 67 ? "wifi" : (forca >= 34 ? "wifi-2" : "wifi-1") }
        Texto {
            visible: (janela.v["wifi.redes"] || []).length === 0
            width: parent.width
            height: 56
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: "Procurando redes…"
            color: janela.corTextoMedio
            font.pixelSize: 13
        }
        Repeater {
            model: janela.v["wifi.redes"] || []
            delegate: Rectangle {
                id: rede
                required property var modelData
                required property int index
                readonly property bool aberta: redes.escolhida === modelData.ssid && modelData.segura && !modelData.conhecida && !modelData.conectada
                width: redes.width
                height: aberta ? 96 : 46
                color: "transparent"
                Rectangle { visible: rede.index > 0; x: 18; width: parent.width - 36; height: 1; color: janela.linha(0.1) }
                RowLayout {
                    x: 18
                    width: parent.width - 36
                    height: 46
                    spacing: 12
                    Image { source: pastaIcones + redes.sinal(rede.modelData.sinal) + janela.iconeForte; sourceSize.width: 18; sourceSize.height: 18 }
                    Texto {
                        Layout.fillWidth: true
                        text: rede.modelData.ssid
                        font.weight: rede.modelData.conectada ? Font.DemiBold : Font.Normal
                    }
                    Texto {
                        visible: janela.v["wifi.conectando"] === rede.modelData.ssid
                        text: "Conectando…"
                        font.pixelSize: 12
                        color: janela.corTextoMedio
                    }
                    Texto {
                        visible: rede.modelData.conectada
                        text: "Conectada"
                        font.pixelSize: 12
                        color: janela.corTextoMedio
                    }
                    Image { visible: rede.modelData.segura; source: pastaIcones + "lock-cinza.svg"; sourceSize.width: 15; sourceSize.height: 15 }
                }
                MouseArea {
                    objectName: "rede:" + rede.modelData.ssid
                    width: parent.width
                    height: 46
                    cursorShape: rede.modelData.conectada ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onClicked: {
                        if (rede.modelData.conectada)
                            return
                        redes.escolhida = rede.modelData.ssid
                        if (!rede.modelData.segura || rede.modelData.conhecida)
                            ajustes.conectarRede(rede.modelData.ssid, "")
                        else
                            senha.forceActiveFocus()
                    }
                }
                RowLayout {
                    visible: rede.aberta
                    x: 18
                    y: 50
                    width: parent.width - 36
                    spacing: 8
                    TextField {
                        id: senha
                        Layout.fillWidth: true
                        implicitHeight: 36
                        echoMode: TextInput.Password
                        passwordCharacter: "•"
                        placeholderText: "Senha da rede"
                        placeholderTextColor: janela.corTextoFraco
                        font.family: "Inter"
                        font.pixelSize: 14
                        color: janela.corTexto
                        leftPadding: 12
                        onAccepted: if (text.length > 0) ajustes.conectarRede(rede.modelData.ssid, text)
                        background: Rectangle {
                            radius: 10
                            color: janela.corCampo
                            border.width: senha.activeFocus ? 1.5 : 1
                            border.color: senha.activeFocus ? "#8b97f6" : janela.linha(0.22)
                        }
                    }
                    Botao {
                        text: "Conectar"
                        enabled: senha.text.length > 0 && !janela.v["wifi.conectando"]
                        onClicked: ajustes.conectarRede(rede.modelData.ssid, senha.text)
                    }
                }
            }
        }
    }

    // Aparelhos Bluetooth já pareados.
    component Aparelhos: Column {
        id: aparelhos
        Texto {
            visible: (janela.v["bluetooth.aparelhos"] || []).length === 0
            width: parent.width
            height: 56
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: "Nenhum aparelho pareado. Para parear um novo, use as opções a mais, abaixo."
            color: janela.corTextoMedio
            font.pixelSize: 13
        }
        Repeater {
            model: janela.v["bluetooth.aparelhos"] || []
            delegate: Item {
                id: aparelho
                required property var modelData
                required property int index
                width: aparelhos.width
                height: 52
                Rectangle { visible: aparelho.index > 0; x: 18; width: parent.width - 36; height: 1; color: janela.linha(0.1) }
                RowLayout {
                    x: 18
                    width: parent.width - 36
                    height: parent.height
                    spacing: 12
                    Image { source: pastaIcones + "bluetooth" + janela.iconeForte; sourceSize.width: 18; sourceSize.height: 18 }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Texto { Layout.fillWidth: true; text: aparelho.modelData.nome; font.weight: Font.Medium }
                        Texto {
                            text: aparelho.modelData.conectado ? "Conectado" : "Desconectado"
                            font.pixelSize: 12
                            color: janela.corTextoMedio
                        }
                    }
                    Botao {
                        objectName: "aparelho:" + aparelho.modelData.mac
                        principal: false
                        text: aparelho.modelData.conectado ? "Desconectar" : "Conectar"
                        onClicked: ajustes.ligarAparelho(aparelho.modelData.mac, !aparelho.modelData.conectado)
                    }
                }
            }
        }
    }

    // Grade de papéis de parede.
    component Fundos: Flow {
        id: fundos
        property string atual: ""
        signal escolhido(string id)
        padding: 14
        spacing: 12
        Repeater {
            model: janela.o["aparencia.fundo"] || []
            delegate: Rectangle {
                id: fundo
                required property var modelData
                readonly property bool marcado: modelData.id === fundos.atual
                width: 140
                height: 88
                radius: 12
                color: janela.linha(0.1)
                border.width: marcado ? 3 : 0
                border.color: "#5f6ce5"
                Image {
                    id: imagem
                    anchors.fill: parent
                    anchors.margins: fundo.marcado ? 5 : 0
                    source: "file://" + fundo.modelData.imagem
                    sourceSize.width: 280
                    sourceSize.height: 176
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: false
                }
                Rectangle { id: recorte; anchors.fill: imagem; radius: fundo.marcado ? 8 : 12; visible: false; layer.enabled: true }
                MultiEffect { anchors.fill: imagem; source: imagem; maskEnabled: true; maskSource: recorte }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (!fundo.marcado) fundos.escolhido(fundo.modelData.id)
                    ToolTip.visible: containsMouse
                    ToolTip.delay: 600
                    ToolTip.text: fundo.modelData.nome
                    hoverEnabled: true
                }
            }
        }
    }

    // Uma linha de ajuste: o título e a explicação à esquerda, a peça à direita.
    // As peças que ocupam a largura toda (redes, aparelhos, fundos) vêm sem título.
    component LinhaDeAjuste: Item {
        id: ajuste
        property var dados: ({})
        property bool primeira: false
        readonly property bool larga: ["redes", "aparelhos", "fundos"].indexOf(dados.tipo) >= 0
        readonly property var valor: dados.chave !== undefined ? janela.v[dados.chave] : undefined
        width: parent ? parent.width : 0
        height: larga ? pecaLarga.height : Math.max(58, textos.implicitHeight + 24)

        Rectangle { visible: !ajuste.primeira && !ajuste.larga; x: 18; width: parent.width - 36; height: 1; color: janela.linha(0.1) }

        ColumnLayout {
            id: textos
            visible: !ajuste.larga
            x: 18
            width: parent.width - 36 - peca.width - 24
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Texto {
                Layout.fillWidth: true
                text: ajuste.dados.titulo || ""
                font.pixelSize: 15
                font.weight: Font.Medium
            }
            Texto {
                visible: text !== ""
                Layout.fillWidth: true
                text: (ajuste.dados.texto || "") + (ajuste.dados.chaveTexto ? janela.mostrar(janela.v[ajuste.dados.chaveTexto]) : "")
                font.pixelSize: 12
                color: janela.corTextoMedio
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
            }
        }
        Loader {
            id: peca
            objectName: "peca:" + (ajuste.dados.chave || ajuste.dados.acao || "")   // para os testes acharem a peça
            visible: !ajuste.larga
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            sourceComponent: {
                switch (ajuste.dados.tipo) {
                case "escolha": return pecaEscolha
                case "segmentos": return pecaSegmentos
                case "interruptor": return pecaInterruptor
                case "barra": return pecaBarra
                case "botao": return pecaBotao
                case "info": return ajuste.dados.chave !== undefined ? pecaInfo : null
                }
                return null
            }
        }
        Loader {
            id: pecaLarga
            active: ajuste.larga
            width: parent.width
            sourceComponent: ajuste.dados.tipo === "redes" ? pecaRedes : (ajuste.dados.tipo === "aparelhos" ? pecaAparelhos : pecaFundos)
        }

        Component {
            id: pecaEscolha
            Escolha {
                implicitWidth: ajuste.dados.largura || 190
                opcoes: janela.o[ajuste.dados.chave] || []
                atual: ajuste.valor !== undefined ? String(ajuste.valor) : ""
                onEscolhido: (id) => ajustes.gravar(ajuste.dados.chave, id)
            }
        }
        Component {
            id: pecaSegmentos
            Segmentos {
                opcoes: janela.o[ajuste.dados.chave] || []
                atual: ajuste.valor !== undefined ? String(ajuste.valor) : ""
                onEscolhido: (id) => ajustes.gravar(ajuste.dados.chave, id)
            }
        }
        Component {
            id: pecaInterruptor
            Interruptor {
                checked: ajuste.valor === true
                // O interruptor mostra sempre o valor do sistema: o clique pede a troca, e a leitura confirma.
                onToggled: {
                    ajustes.gravar(ajuste.dados.chave, checked)
                    checked = Qt.binding(() => ajuste.valor === true)
                }
            }
        }
        Component {
            id: pecaBarra
            Deslizante {
                valor: ajuste.valor !== undefined ? ajuste.valor : 0
                minimo: ajuste.dados.minimo || 0
                onMudou: (novo) => ajustes.gravar(ajuste.dados.chave, novo)
            }
        }
        Component {
            id: pecaBotao
            Botao {
                principal: false
                text: ajuste.dados.rotulo || "Abrir"
                onClicked: janela.fazer(ajuste.dados.acao)
            }
        }
        Component {
            id: pecaInfo
            Texto {
                width: Math.min(implicitWidth, 420)
                horizontalAlignment: Text.AlignRight
                text: janela.mostrar(ajuste.valor)
                font.pixelSize: 13
                color: janela.corTextoMedio
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
            }
        }
        Component { id: pecaRedes; Redes { } }
        Component { id: pecaAparelhos; Aparelhos { } }
        Component {
            id: pecaFundos
            Fundos {
                atual: ajuste.valor !== undefined ? String(ajuste.valor) : ""
                onEscolhido: (id) => ajustes.gravar(ajuste.dados.chave, id)
            }
        }
    }

    // ---------------- janela ----------------

    Item {
        id: painel
        x: janela.margem
        y: janela.margem
        width: janela.width - 2 * janela.margem
        height: janela.height - 2 * janela.margem

        // Sombra da janela. No Wayland, uma janela sem moldura não ganha sombra do
        // sistema: ela é desenhada na faixa transparente em volta do painel.
        RectangularShadow {
            anchors.fill: parent
            radius: janela.raio
            blur: 48
            spread: -6
            offset.y: 14
            color: Qt.rgba(0.16, 0.13, 0.35, 0.28)
        }
        Rectangle {
            anchors.fill: parent
            radius: janela.raio
            gradient: Gradient {
                GradientStop { position: 0.0; color: janela.corLateralCima }
                GradientStop { position: 1.0; color: janela.corLateralBaixo }
            }
        }
        // Área das páginas: mais clara, com os cantos da direita arredondados.
        Item {
            x: janela.lateral
            width: parent.width - janela.lateral
            height: parent.height
            clip: true
            Rectangle { x: -30; width: parent.width + 30; height: parent.height; radius: janela.raio; color: janela.corConteudo }
        }
        Rectangle {
            anchors.fill: parent
            radius: janela.raio
            color: "transparent"
            border.width: 1
            border.color: janela.brilho(0.95)
        }

        // Arrastar pelo topo move a janela.
        MouseArea {
            width: parent.width
            height: 52
            onPressed: janela.startSystemMove()
        }
        BotoesDaJanela {
            x: 22
            y: 21
            alvo: janela
            podeMaximizar: false
            onFechar: Qt.quit()
        }

        // ---------------- barra lateral ----------------

        Column {
            x: 14
            y: 60
            width: janela.lateral - 28
            spacing: 2
            Repeater {
                model: janela.secoes
                delegate: Rectangle {
                    id: entrada
                    required property var modelData
                    readonly property bool atual: janela.pagina === modelData.id
                    width: parent.width
                    height: 38
                    radius: 11
                    color: atual ? Qt.rgba(0.49, 0.45, 0.92, janela.escuro ? 0.32 : 0.17)
                                 : (areaEntrada.containsMouse ? janela.brilho(0.5) : "transparent")
                    border.width: atual ? 1 : 0
                    border.color: janela.brilho(0.6)
                    Image {
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        source: pastaIcones + entrada.modelData.icone + janela.iconeForte
                        sourceSize.width: 18
                        sourceSize.height: 18
                    }
                    Texto {
                        x: 42
                        anchors.verticalCenter: parent.verticalCenter
                        text: entrada.modelData.nome
                        font.pixelSize: 14
                        font.weight: entrada.atual ? Font.DemiBold : Font.Normal
                    }
                    MouseArea {
                        id: areaEntrada
                        objectName: "pagina:" + entrada.modelData.id
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: janela.pagina = entrada.modelData.id
                    }
                }
            }
        }

        // ---------------- página ----------------

        Flickable {
            id: rolagem
            x: janela.lateral
            y: 14
            width: parent.width - janela.lateral
            height: parent.height - 28
            contentHeight: conteudo.height + 24
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { }

            Column {
                id: conteudo
                x: 32
                y: 8
                width: parent.width - 64
                spacing: 0

                Texto {
                    height: 54
                    text: janela.secao ? janela.secao.nome : ""
                    font.pixelSize: 24
                    font.weight: Font.Bold
                }

                Repeater {
                    model: janela.paginas[janela.pagina] || []
                    delegate: Column {
                        id: grupo
                        required property var modelData
                        visible: janela.vale(modelData.se)
                        width: conteudo.width
                        Texto {
                            visible: grupo.modelData.titulo !== undefined
                            height: 34
                            verticalAlignment: Text.AlignVCenter
                            text: grupo.modelData.titulo || ""
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            color: janela.corTextoMedio
                        }
                        Rectangle {
                            width: parent.width
                            height: linhasDoGrupo.height
                            radius: 16
                            color: janela.corCartao
                            border.width: 1
                            border.color: janela.linha(0.1)
                            Column {
                                id: linhasDoGrupo
                                width: parent.width
                                Repeater {
                                    model: grupo.modelData.linhas
                                    delegate: LinhaDeAjuste {
                                        required property var modelData
                                        required property int index
                                        dados: modelData
                                        visible: janela.vale(modelData.se)
                                        // A primeira linha que aparece não leva o traço de cima.
                                        primeira: grupo.modelData.linhas.slice(0, index).every(l => !janela.vale(l.se))
                                    }
                                }
                            }
                        }
                        Item { width: 1; height: 14 }
                    }
                }

                // Atalho para o módulo das Configurações do Sistema com o resto das opções.
                Item {
                    visible: janela.secao !== undefined && janela.secao.mais !== ""
                    width: parent.width
                    height: 40
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        Texto {
                            id: textoMais
                            text: "Mais opções nas Configurações do Sistema"
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            color: areaMais.containsMouse ? "#5f6ce5" : janela.corTextoMedio
                        }
                        Image {
                            anchors.verticalCenter: parent.verticalCenter
                            source: pastaIcones + "chevron-right-cinza.svg"
                            sourceSize.width: 14
                            sourceSize.height: 14
                        }
                    }
                    MouseArea {
                        id: areaMais
                        objectName: "mais"
                        width: textoMais.implicitWidth + 24
                        height: parent.height
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ajustes.maisOpcoes(janela.secao.mais)
                    }
                }
            }
        }

        // Depois de trocar a resolução ou a taxa: confirmar, ou a tela volta sozinha.
        Rectangle {
            visible: janela.v["tela.confirmar"] === true
            anchors.horizontalCenter: rolagem.horizontalCenter
            y: parent.height - height - 18
            width: 520
            height: 58
            radius: 16
            color: "#2b2840"
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: 12
                spacing: 10
                Texto {
                    Layout.fillWidth: true
                    text: "Manter esta imagem? Sem resposta, volta em 15 segundos."
                    font.pixelSize: 13
                    color: "#ffffff"
                    wrapMode: Text.WordWrap
                    elide: Text.ElideNone
                }
                Botao { principal: false; text: "Voltar"; onClicked: ajustes.desfazerModo() }
                Botao { text: "Manter"; onClicked: ajustes.manterModo() }
            }
        }

        // Aviso curto, no rodapé.
        Rectangle {
            visible: janela.mensagem !== ""
            anchors.horizontalCenter: rolagem.horizontalCenter
            y: parent.height - height - 18
            width: textoAviso.implicitWidth + 36
            height: 38
            radius: 19
            color: "#2b2840"
            Texto {
                id: textoAviso
                anchors.centerIn: parent
                text: janela.mensagem
                font.pixelSize: 13
                color: "#ffffff"
            }
        }
    }
}
