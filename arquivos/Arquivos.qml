// Arquivos do bmos, no estilo do Finder do Mac: barra lateral de vidro com
// Favoritos e Locais, barra de ferramentas, grade ou lista, e o caminho no rodapé.
// Quem lê as pastas e move os arquivos é o objeto "arquivos" (arquivos.py).
// A janela é aberta pelo bmos-arquivos.py, um processo por janela.
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Window
import "../app-comum"

Window {
    id: janela

    readonly property bool cheia: visibility === Window.Maximized || visibility === Window.FullScreen
    readonly property int margem: cheia ? 0 : 56     // faixa em volta, só para a sombra
    readonly property int raio: cheia ? 0 : 24
    readonly property int lateral: 216

    // Cores da janela nos modos claro e escuro. O modo acompanha o tema do bmos.
    readonly property bool escuro: sistema.escuro
    readonly property color corTexto: escuro ? "#f2f0fa" : "#1f1d2b"
    readonly property color corTextoLateral: escuro ? "#d9d5ee" : "#3d3a4f"
    readonly property color corTextoMedio: escuro ? "#aaa6c6" : "#6b6880"
    readonly property color corTextoFraco: escuro ? "#8d89aa" : "#8f8ca3"
    readonly property color corTextoPrevia: escuro ? "#e4e1f3" : "#2b2840"
    readonly property color corCartao: escuro ? "#2f2c4b" : "#ffffff"
    readonly property color corConteudo: escuro ? "#1e1c36" : "#fbfaff"
    readonly property color corLateralCima: escuro ? "#2b2849" : "#ecebfa"
    readonly property color corLateralBaixo: escuro ? "#262343" : "#e7e3f4"
    readonly property color corSelecaoTexto: escuro ? "#4a54b8" : "#c5caf9"
    // Quanto aparece um botão que não pode ser usado agora (voltar sem histórico, por
    // exemplo). No escuro precisa aparecer mais, senão some no fundo.
    readonly property real apagado: escuro ? 0.6 : 0.4
    // Ícones de traço: brancos no escuro, grafite no claro.
    readonly property string iconeForte: escuro ? "-branco.svg" : "-escuro.svg"
    // Linhas e fundos discretos: lilás acinzentado no claro, branco fraco no escuro.
    function linha(forca) { return escuro ? Qt.rgba(1, 1, 1, forca * 1.1) : Qt.rgba(0.43, 0.41, 0.63, forca) }
    // Brilhos e bordas claras: branco no claro, quase apagado no escuro.
    function brilho(forca) { return escuro ? Qt.rgba(1, 1, 1, forca * 0.13) : Qt.rgba(1, 1, 1, forca) }

    property string caminho: ""
    property var dados: ({ nome: "", pai: "", livre: "", partes: [], gravavel: false, existe: true })
    property var todos: []            // tudo que a pasta tem
    property var itens: []            // o que aparece, depois da busca e da ordem
    property var selecao: []          // caminhos marcados
    property int ancora: -1           // de onde parte a seleção com Shift
    property var historico: []
    property int posicao: -1
    property string modo: "icones"    // "icones" ou "lista"
    property int tamanho: 72          // tamanho dos ícones na grade
    property bool ocultos: false
    property string filtro: ""
    property string ordem: "nome"     // "nome", "modificado", "tamanho" ou "tipo"
    property bool crescente: true
    property string renomeando: ""
    property var favoritos: []
    property var locais: []
    property string alvoMenu: ""      // item da barra lateral que abriu o menu
    property var alvoLateral: ({ grupo: "", item: ({}) })     // o mesmo item, inteiro, e o grupo dele
    property string renomeandoLateral: ""                     // "grupo|chave" do item com o nome em edição
    property var arrasto: ({ grupo: "", de: -1, para: -1 })   // item da barra lateral sendo arrastado
    property string mensagem: ""
    // O que o menu oferece depende do que existe no sistema: é conferido uma vez, ao abrir.
    property bool temArk: false
    property bool temFilelight: false
    property bool temDolphin: false
    property var coresDePasta: []
    // Pré-visualização (Espaço): o que o arquivos.previa() devolveu para o item marcado.
    property bool espiando: false
    property var espiada: ({})
    onSelecaoChanged: if (espiando) espiar()

    function espiar() {
        if (selecao.length !== 1 || caminho === "lixeira:") {
            espiando = false
            return
        }
        const dados = arquivos.previa(selecao[0])
        espiada = dados
        espiando = dados.nome !== undefined
    }

    readonly property bool especial: caminho === "lixeira:" || caminho === "recentes:"
    readonly property string textoArrasto: arquivos.enderecos(selecao).join("\r\n") + "\r\n"
    readonly property string estadoTexto: {
        const n = itens.length
        const t = selecao.length > 0
                ? selecao.length + " de " + n + (selecao.length === 1 ? " selecionado" : " selecionados")
                : (n === 1 ? "1 item" : n + " itens")
        return dados.livre !== "" ? t + "  ·  " + dados.livre : t
    }

    flags: Qt.FramelessWindowHint | Qt.Window
    color: "transparent"
    title: "Arquivos"
    visible: false
    width: 1010 + 2 * 56
    height: 650 + 2 * 56
    minimumWidth: 720 + 2 * margem
    minimumHeight: 460 + 2 * margem

    // ---------------- navegação ----------------

    function ir(novo, semHistorico) {
        if (novo === "" || novo === undefined)
            return
        arquivos.observar(caminho, novo)
        caminho = novo
        if (!semHistorico) {
            historico = historico.slice(0, posicao + 1).concat([novo])
            posicao = historico.length - 1
        }
        filtro = ""
        campoBusca.text = ""
        selecao = []
        ancora = -1
        renomeando = ""
        recarregar(true)
    }
    function recarregar(doInicio) {
        if (caminho === "")
            return
        dados = arquivos.info(caminho)
        if (!dados.existe) {            // a pasta sumiu (pendrive removido, pasta apagada)
            ir(arquivos.casa)
            return
        }
        todos = arquivos.listar(caminho, ocultos)
        const existentes = new Set(todos.map(i => i.caminho))
        selecao = selecao.filter(c => existentes.has(c))
        filtrar(doInicio)
    }
    function filtrar(doInicio) {
        let lista = todos
        const termo = filtro.trim().toLowerCase()
        if (termo !== "")
            lista = lista.filter(i => i.nome.toLowerCase().indexOf(termo) >= 0)
        if (ordem !== "nome" || !crescente) {
            const campo = ({ nome: "nome", modificado: "modificado", tamanho: "tamanho", tipo: "tipo" })[ordem]
            lista = lista.slice().sort((a, b) => {
                if (a.pasta !== b.pasta)
                    return a.pasta ? -1 : 1
                let r = 0
                if (campo === "nome" || campo === "tipo")
                    r = a[campo].localeCompare(b[campo], "pt", { numeric: true, sensitivity: "base" })
                else
                    r = a[campo] - b[campo]
                return crescente ? r : -r
            })
        }
        const yGrade = grade.contentY, yLista = lista2.contentY
        itens = lista
        if (!doInicio) {
            grade.contentY = Math.min(yGrade, Math.max(0, grade.contentHeight - grade.height))
            lista2.contentY = Math.min(yLista, Math.max(0, lista2.contentHeight - lista2.height))
        }
    }
    function voltar() { if (posicao > 0) { posicao -= 1; ir(historico[posicao], true) } }
    function avancar() { if (posicao < historico.length - 1) { posicao += 1; ir(historico[posicao], true) } }
    function subir() { if (dados.pai !== "") ir(dados.pai) }
    function abrirItem(item) {
        if (!item || caminho === "lixeira:")
            return
        item.pasta ? ir(item.caminho) : arquivos.abrir(item.caminho)
    }
    function abrirLocal(local) {
        if (local.caminho !== "") {
            ir(local.caminho)
        } else if (local.dispositivo !== "") {
            const pasta = arquivos.montar(local.dispositivo)
            if (pasta !== "")
                ir(pasta)
        }
    }

    // ---------------- seleção ----------------

    function clicar(indice, modificadores) {
        const c = itens[indice].caminho
        if ((modificadores & Qt.ShiftModifier) && ancora >= 0 && ancora < itens.length) {
            const a = Math.min(ancora, indice), b = Math.max(ancora, indice)
            selecao = itens.slice(a, b + 1).map(i => i.caminho)
        } else if (modificadores & Qt.ControlModifier) {
            selecao = selecao.indexOf(c) >= 0 ? selecao.filter(x => x !== c) : selecao.concat([c])
            ancora = indice
        } else {
            selecao = [c]
            ancora = indice
        }
    }
    function andar(passo) {
        if (itens.length === 0)
            return
        const atual = selecao.length > 0 ? itens.findIndex(i => i.caminho === selecao[selecao.length - 1]) : -1
        const novo = atual < 0 ? 0 : Math.max(0, Math.min(itens.length - 1, atual + passo))
        selecao = [itens[novo].caminho]
        ancora = novo
        if (modo === "icones")
            grade.positionViewAtIndex(novo, GridView.Contain)
        else
            lista2.positionViewAtIndex(novo, ListView.Contain)
    }

    // ---------------- ações ----------------

    function novaPasta() {
        if (especial || !dados.gravavel)
            return
        const pasta = arquivos.novaPasta(caminho)
        if (pasta !== "") {
            recarregar()
            selecao = [pasta]
            renomeando = pasta
        }
    }
    function novoArquivo(nome) {
        if (especial || !dados.gravavel)
            return
        const arquivo = arquivos.novoArquivo(caminho, nome)
        if (arquivo !== "") {
            recarregar()
            selecao = [arquivo]
            renomeando = arquivo
        }
    }
    function concluirRenomear(item, texto) {
        if (renomeando !== item)
            return
        renomeando = ""
        const novo = arquivos.renomear(item, texto)
        recarregar()
        if (novo !== "")
            selecao = [novo]
        conteudo.forceActiveFocus()
    }
    function executar(id) {
        const marcados = selecao.slice()
        // Alvo das ações de um item só: o item marcado ou, no menu do vazio, a pasta aberta.
        const alvo = marcados.length > 0 ? marcados[0] : caminho
        switch (id) {
        case "latAbrir": alvoLateral.grupo === "locais" ? abrirLocal(alvoLateral.item) : ir(alvoLateral.item.caminho); break
        case "latNovaJanela": arquivos.novaJanela(alvoLateral.item.caminho); break
        case "latRenomear": renomeandoLateral = alvoLateral.grupo + "|" + alvoLateral.item.chave; break
        case "latRetirar": arquivos.removerFavorito(alvoLateral.item.caminho); break
        case "latPropriedades": arquivos.propriedades(alvoLateral.item.caminho); break
        case "latRestaurar": arquivos.restaurarLateral(); break
        case "novajanela": arquivos.novaJanela(alvo); break
        case "terminalAqui": arquivos.abrirTerminal(alvo); break
        case "copiarLocal":
            arquivos.copiarTexto(marcados.length > 0 ? marcados.join("\n") : caminho)
            avisar("Localização copiada.")
            break
        case "novoTexto": novoArquivo("Novo arquivo.txt"); break
        case "novoVazio": novoArquivo("Novo arquivo"); break
        case "moverNova": {
            const pasta = arquivos.moverParaNovaPasta(marcados)
            if (pasta !== "") {
                recarregar()
                selecao = [pasta]
                renomeando = pasta
            }
            break
        }
        case "extrair": arquivos.extrair(marcados, false); break
        case "extrairPara": arquivos.extrair(marcados, true); break
        case "uso": arquivos.usoDoDisco(alvo); break
        case "propriedades": arquivos.propriedades(alvo); break
        case "dolphin": arquivos.abrirNoDolphin(alvo); break
        case "recarregar": recarregar(); break
        case "inverter": crescente = !crescente; filtrar(true); break
        case "abrir": abrirItem(itens.find(i => i.caminho === marcados[0])); break
        case "recortar": arquivos.copiar(marcados, true); break
        case "copiar": arquivos.copiar(marcados, false); break
        case "colar": arquivos.colar(caminho); break
        case "duplicar": arquivos.duplicar(marcados); break
        case "renomear": renomeando = marcados[0]; break
        case "favorito": arquivos.adicionarFavorito(marcados[0]); break
        case "lixeira": arquivos.paraLixeira(marcados); selecao = []; break
        case "restaurar": arquivos.restaurar(marcados); selecao = []; break
        case "esvaziar": arquivos.esvaziarLixeira(); break
        case "nova": novaPasta(); break
        case "tudo": selecao = itens.map(i => i.caminho); break
        case "ocultos": ocultos = !ocultos; recarregar(); break
        case "terminal": arquivos.abrirTerminal(caminho); break
        case "removerFavorito": arquivos.removerFavorito(alvoMenu); break
        case "ejetar": arquivos.ejetar(alvoMenu); break
        case "espiar": espiar(); break
        case "papel":
            avisar(sistema.usarComoPapel(marcados[0]) ? "Papel de parede trocado."
                                                      : "Não foi possível usar esta imagem.")
            break
        default:
            if (id.indexOf("com:") === 0)
                arquivos.abrirCom(id.slice(4), marcados[0])
            else if (id.indexOf("compactar:") === 0)
                arquivos.compactar(marcados, id.slice(10))
            else if (id.indexOf("cor:") === 0)
                arquivos.corDaPasta(alvo, id.slice(4))
            else if (id.indexOf("ordem:") === 0) {
                ordem = id.slice(6)
                filtrar(true)
            }
        }
    }
    // Cada entrada do menu: id (ação), nome, icone (traço), tema (ícone do tema de ícones),
    // atalho (texto à direita), marcado (visto à direita) e filhos (submenu ao lado).
    // "apps: true" é o submenu dos apps que abrem o item, montado na hora.
    function menuDeItem() {
        if (caminho === "lixeira:")
            return [{ id: "restaurar", nome: "Devolver ao lugar de origem", icone: "restore" }]
        const um = selecao.length === 1
        const item = itens.find(i => i.caminho === selecao[0])
        const marcados = itens.filter(i => selecao.indexOf(i.caminho) >= 0)
        const recentes = caminho === "recentes:"
        const pasta = um && item && item.pasta
        const e = []
        if (um) {
            e.push({ id: "abrir", nome: "Abrir", icone: "external-link", atalho: "Enter" })
            if (pasta)
                e.push({ id: "novajanela", nome: "Abrir em nova janela", icone: "layout-grid" })
            if (item && !recentes)
                e.push({ nome: pasta ? "Abrir pasta com" : "Abrir com", icone: "dots", apps: true })
            e.push({ id: "espiar", nome: "Pré-visualizar", icone: "search", atalho: "Espaço" })
            if (item && /\.(png|jpe?g|svg)$/i.test(item.nome))
                e.push({ id: "papel", nome: "Usar como papel de parede", icone: "photo" })
            e.push({ separador: true })
        }
        e.push({ id: "recortar", nome: "Recortar", icone: "scissors", atalho: "Ctrl+X" },
               { id: "copiar", nome: "Copiar", icone: "copy", atalho: "Ctrl+C" },
               { id: "copiarLocal", nome: "Copiar localização", icone: "clipboard", atalho: "Ctrl+Alt+C" })
        if (!recentes) {
            e.push({ id: "duplicar", nome: "Duplicar", icone: "copy", atalho: "Ctrl+D" })
            if (um)
                e.push({ id: "renomear", nome: "Renomear", icone: "pencil", atalho: "F2" })
            else
                e.push({ id: "moverNova", nome: "Mover para nova pasta", icone: "folder-plus" })
        }
        if (pasta)
            e.push({ id: "favorito", nome: "Adicionar aos Favoritos", icone: "plus" })
        e.push({ separador: true }, { id: "lixeira", nome: "Mover para a Lixeira", icone: "trash", atalho: "Del" },
               { separador: true })
        if (pasta) {
            e.push({ id: "terminalAqui", nome: "Abrir terminal aqui", icone: "terminal-2" })
            if (temFilelight)
                e.push({ id: "uso", nome: "Uso do disco", icone: "gauge" })
        }
        if (temArk) {
            if (marcados.length > 0 && marcados.every(i => !i.pasta && /\.(zip|rar|7z|tar|tgz|tbz2|txz|gz|bz2|xz|zst)$/i.test(i.nome)))
                e.push({ nome: "Extrair", icone: "download", filhos: [
                    { id: "extrair", nome: "Extrair aqui", icone: "download" },
                    { id: "extrairPara", nome: "Extrair para…", icone: "folder" }] })
            e.push({ nome: "Compactar", icone: "cloud-download", filhos: [
                { id: "compactar:zip", nome: "Aqui, em ZIP", icone: "file-text" },
                { id: "compactar:tar.gz", nome: "Aqui, em TAR.GZ", icone: "file-text" },
                { id: "compactar:", nome: "Compactar para…", icone: "folder" }] })
        }
        if (pasta && !recentes && coresDePasta.length > 0)
            e.push({ nome: "Cor da pasta", icone: "palette", filhos:
                [{ id: "cor:", nome: "Padrão", tema: "folder" }].concat(
                    coresDePasta.map(c => ({ id: "cor:" + c.icone, nome: c.nome, tema: c.icone }))) })
        if (um) {
            if (temDolphin)
                e.push({ id: "dolphin", nome: "Abrir no Dolphin", icone: "external-link" })
            e.push({ separador: true }, { id: "propriedades", nome: "Propriedades", icone: "info-circle", atalho: "Alt+Enter" })
        }
        return e
    }
    // Menu de um item da barra lateral, como o do painel de locais do Dolphin.
    function menuDaLateral(item, grupo) {
        const pasta = item.caminho !== "" && item.caminho !== "recentes:" && item.caminho !== "lixeira:"
        const e = [{ id: "latAbrir", nome: "Abrir", icone: "external-link" }]
        if (pasta)
            e.push({ id: "latNovaJanela", nome: "Abrir em nova janela", icone: "layout-grid" })
        e.push({ separador: true }, { id: "latRenomear", nome: "Renomear", icone: "pencil" })
        if (grupo === "favoritos")
            e.push({ id: "latRetirar", nome: "Retirar dos Favoritos", icone: "minus" })
        if (item.removivel && item.montado)
            e.push({ id: "ejetar", nome: "Ejetar", icone: "player-eject" })
        if (item.caminho === "lixeira:")
            e.push({ id: "esvaziar", nome: "Esvaziar Lixeira", icone: "trash" })
        if (pasta)
            e.push({ separador: true }, { id: "latPropriedades", nome: "Propriedades", icone: "info-circle" })
        return e
    }
    function menuDeFundo() {
        if (caminho === "lixeira:")
            return itens.length > 0 ? [{ id: "esvaziar", nome: "Esvaziar Lixeira", icone: "trash" }] : []
        if (caminho === "recentes:")
            return []
        const e = []
        if (dados.gravavel)
            e.push({ nome: "Criar novo", icone: "plus", filhos: [
                { id: "nova", nome: "Pasta", icone: "folder-plus", atalho: "Ctrl+Shift+N" },
                { id: "novoTexto", nome: "Arquivo de texto", icone: "file-text" },
                { id: "novoVazio", nome: "Arquivo vazio", icone: "file-text" }] })
        if (arquivos.podeColar)
            e.push({ id: "colar", nome: "Colar", icone: "clipboard", atalho: "Ctrl+V" })
        const ordens = [["nome", "Nome"], ["modificado", "Data de modificação"], ["tamanho", "Tamanho"], ["tipo", "Tipo"]]
        e.push({ separador: true },
               { id: "tudo", nome: "Selecionar tudo", icone: "check", atalho: "Ctrl+A" },
               { id: "ocultos", nome: ocultos ? "Esconder arquivos ocultos" : "Mostrar arquivos ocultos", icone: "dots", atalho: "Ctrl+H" },
               { nome: "Ordenar por", icone: "list", filhos: ordens.map(o => ({ id: "ordem:" + o[0], nome: o[1], marcado: ordem === o[0] }))
                   .concat([{ separador: true }, { id: "inverter", nome: "Ordem decrescente", marcado: !crescente }]) },
               { id: "recarregar", nome: "Atualizar", icone: "refresh", atalho: "F5" },
               { separador: true },
               { id: "novajanela", nome: "Abrir em nova janela", icone: "layout-grid", atalho: "Ctrl+N" },
               { id: "terminal", nome: "Abrir terminal aqui", icone: "terminal-2" },
               { id: "copiarLocal", nome: "Copiar localização", icone: "clipboard", atalho: "Ctrl+Alt+C" })
        if (temFilelight)
            e.push({ id: "uso", nome: "Uso do disco", icone: "gauge" })
        if (temDolphin)
            e.push({ id: "dolphin", nome: "Abrir no Dolphin", icone: "external-link" })
        e.push({ separador: true }, { id: "propriedades", nome: "Propriedades", icone: "info-circle", atalho: "Alt+Enter" })
        return e
    }
    // Apps que abrem o item marcado, como entradas de submenu. A lista é montada só
    // quando o submenu abre, porque consultar o sistema leva um instante.
    function appsDoMarcado() {
        const apps = selecao.length > 0 ? arquivos.appsPara(selecao[0]) : []
        if (apps.length === 0)
            return [{ nome: "Nenhum app para este tipo", inativa: true }]
        return apps.map(a => ({ id: "com:" + a.arquivo, nome: a.nome, tema: a.icone || "" }))
    }
    // x e y são a posição do clique dentro do painel da janela.
    function abrirMenu(entradas, x, y) {
        if (entradas.length === 0)
            return
        menu.close()
        menu.entradas = entradas
        // O menu é uma janela: a posição é contada a partir do canto da janela do Arquivos.
        menu.x = janela.x + painel.x + x - menu.folga
        menu.y = janela.y + painel.y + y - menu.folga
        menu.open()
    }
    function avisar(texto) {
        mensagem = texto
        tempoAviso.restart()
    }
    function focar() { conteudo.forceActiveFocus() }
    function cliqueNoVazio(area, mouse) {
        conteudo.forceActiveFocus()
        selecao = []
        if (mouse.button === Qt.RightButton) {
            const p = area.mapToItem(painel, mouse.x, mouse.y)
            abrirMenu(menuDeFundo(), p.x, p.y)
        }
    }

    // ---------------- abrir e fechar ----------------

    function mostrar(destino) {
        if (destino !== "" && destino !== caminho)
            ir(destino)
        else
            recarregar()
        if (!visible) {
            painel.opacity = 0
            painel.scale = 0.98
            entrada.restart()
        }
        visible = true
        if (visibility === Window.Minimized)
            showNormal()
        raise()
        requestActivate()
        conteudo.forceActiveFocus()
    }
    // Fechar a janela encerra o app.
    function esconder() {
        arquivos.observar(caminho, "")
        Qt.quit()
    }

    Component.onCompleted: {
        favoritos = arquivos.favoritos()
        locais = arquivos.locais()
        temArk = arquivos.temComando("ark")
        temFilelight = arquivos.temComando("filelight")
        temDolphin = arquivos.temComando("dolphin")
        coresDePasta = arquivos.coresDePasta()
        // A pasta pedida na linha de comando, ou a pasta pessoal.
        mostrar(pastaInicial !== "" ? arquivos.resolver(pastaInicial) : arquivos.casa)
    }
    Connections {
        target: arquivos
        function onPastaMudou(pasta) {
            if (pasta === janela.caminho && janela.renomeando === "")
                janela.recarregar()
        }
        function onLocaisMudaram() { janela.locais = arquivos.locais(); if (janela.visible) janela.recarregar() }
        function onFavoritosMudaram() { janela.favoritos = arquivos.favoritos() }
        function onAviso(texto) { janela.avisar(texto) }
    }
    // Com o menu aberto: Esc fecha, um clique em qualquer lugar da janela fecha e
    // segue para onde foi dado, e trocar de janela também fecha.
    Shortcut { sequence: "Escape"; enabled: menu.visible; onActivated: menu.close() }
    onActiveChanged: if (!active) fechaAoTrocar.restart()
    // A espera evita fechar o menu no meio de um clique dado nele mesmo.
    Timer {
        id: fechaAoTrocar
        interval: 150
        onTriggered: if (!janela.active && menu.sobre < 0 && submenu.sobre < 0) menu.close()
    }
    MouseArea {
        anchors.fill: parent
        z: 1000
        visible: menu.visible
        acceptedButtons: Qt.AllButtons
        onPressed: (mouse) => {
            menu.close()
            mouse.accepted = false
        }
        onWheel: (roda) => {
            menu.close()
            roda.accepted = false
        }
    }
    Shortcut { sequence: "Ctrl+W"; onActivated: janela.esconder() }
    Shortcut { sequence: "Ctrl+F"; onActivated: campoBusca.forceActiveFocus() }
    Timer { id: tempoAviso; interval: 3800; onTriggered: janela.mensagem = "" }

    ParallelAnimation {
        id: entrada
        NumberAnimation { target: painel; property: "opacity"; to: 1; duration: 150; easing.type: Easing.OutCubic }
        NumberAnimation { target: painel; property: "scale"; to: 1; duration: 170; easing.type: Easing.OutCubic }
    }

    // ---------------- peças ----------------

    // Linha da barra lateral.
    // Uma linha da barra lateral. Dentro do grupo dela (Favoritos ou Locais), pode ser
    // arrastada para outra posição: as vizinhas abrem espaço enquanto ela passa.
    component Entrada: Rectangle {
        id: linhaLateral
        property string nome: ""
        property string icone: "folder"
        property string destino: ""
        property bool ejetavel: false
        property string grupo: ""         // "favoritos" ou "locais"
        property string chave: ""         // como o motor reconhece este item
        property int indice: 0
        property int total: 1
        property bool atual: false
        property bool arrastando: false
        property real desloc: 0
        readonly property int passo: 34   // altura da linha mais o espaço até a próxima
        readonly property bool editando: chave !== "" && janela.renomeandoLateral === grupo + "|" + chave
        // Quanto esta linha se afasta para dar lugar à que está sendo arrastada.
        readonly property real cede: {
            const a = janela.arrasto
            if (a.grupo !== grupo || arrastando || a.de < 0)
                return 0
            if (a.de < a.para && indice > a.de && indice <= a.para)
                return -passo
            if (a.para < a.de && indice >= a.para && indice < a.de)
                return passo
            return 0
        }
        signal clicado()
        signal menuPedido(real px, real py)
        signal ejetar()
        signal movido(int para)
        signal renomeado(string nome)

        function soltar(valer) {
            if (!arrastando)
                return
            const para = janela.arrasto.para
            arrastando = false
            desloc = 0
            janela.arrasto = { grupo: "", de: -1, para: -1 }
            if (valer && para >= 0 && para !== indice)
                movido(para)
        }

        width: parent ? parent.width : 0
        height: 32
        radius: 9
        z: arrastando ? 5 : 0
        color: atual ? Qt.rgba(0.49, 0.45, 0.92, janela.escuro ? 0.32 : 0.17)
                     : (arrastando ? janela.brilho(0.8)
                        : (areaLateral.containsMouse || soltaLateral.containsDrag ? janela.brilho(0.5) : "transparent"))
        border.width: atual || arrastando ? 1 : 0
        border.color: janela.brilho(0.6)
        transform: Translate {
            y: linhaLateral.arrastando ? linhaLateral.desloc : linhaLateral.cede
            Behavior on y { enabled: !linhaLateral.arrastando; NumberAnimation { duration: 110 } }
        }
        Image {
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            source: pastaIcones + linhaLateral.icone + "-destaque.svg"
            sourceSize.width: 18
            sourceSize.height: 18
        }
        Texto {
            visible: !linhaLateral.editando
            x: 38
            width: parent.width - 38 - (linhaLateral.ejetavel ? 34 : 8)
            anchors.verticalCenter: parent.verticalCenter
            text: linhaLateral.nome
            font.pixelSize: 13
            font.weight: linhaLateral.atual ? Font.DemiBold : Font.Normal
            color: linhaLateral.atual ? janela.corTexto : janela.corTextoLateral
        }
        MouseArea {
            id: areaLateral
            property real inicio: 0
            property bool moveu: false
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            // A barra lateral rola: sem isto ela tomaria o arrasto para si.
            preventStealing: true
            onPressed: (mouse) => {
                inicio = mapToItem(null, mouse.x, mouse.y).y
                moveu = false
            }
            onPositionChanged: (mouse) => {
                if (!(pressedButtons & Qt.LeftButton) || linhaLateral.grupo === "" || linhaLateral.total < 2)
                    return
                // A posição é medida na janela, porque a linha se move junto com o mouse.
                const andou = mapToItem(null, mouse.x, mouse.y).y - inicio
                if (!linhaLateral.arrastando && Math.abs(andou) > 6) {
                    linhaLateral.arrastando = true
                    moveu = true
                }
                if (linhaLateral.arrastando) {
                    const p = linhaLateral.passo
                    linhaLateral.desloc = Math.max(-linhaLateral.indice * p,
                                                   Math.min((linhaLateral.total - 1 - linhaLateral.indice) * p, andou))
                    janela.arrasto = { grupo: linhaLateral.grupo, de: linhaLateral.indice,
                                       para: linhaLateral.indice + Math.round(linhaLateral.desloc / p) }
                }
            }
            onReleased: linhaLateral.soltar(true)
            onCanceled: linhaLateral.soltar(false)
            onClicked: (mouse) => {
                if (moveu)
                    return
                if (mouse.button === Qt.RightButton)
                    linhaLateral.menuPedido(mouse.x, mouse.y)
                else
                    linhaLateral.clicado()
            }
        }
        // Campo para trocar o nome que aparece na barra lateral.
        Loader {
            active: linhaLateral.editando
            x: 32
            width: parent.width - 38
            anchors.verticalCenter: parent.verticalCenter
            sourceComponent: TextField {
                id: campoLateral
                property bool teveFoco: false
                property bool concluido: false
                function concluir(valer) {
                    if (concluido)
                        return
                    concluido = true
                    // Fechar a edição apaga este campo. O que for usado depois disso é guardado antes.
                    const tela = janela, linha = linhaLateral, valor = text
                    const mudou = valer && valor.trim() !== linha.nome
                    tela.renomeandoLateral = ""
                    if (mudou)
                        linha.renomeado(valor)
                    tela.focar()
                }
                text: linhaLateral.nome
                font.family: "Inter"
                font.pixelSize: 13
                color: janela.corTexto
                selectionColor: janela.corSelecaoTexto
                selectedTextColor: janela.corTexto
                selectByMouse: true
                topPadding: 3
                bottomPadding: 3
                leftPadding: 6
                rightPadding: 6
                background: Rectangle { radius: 7; color: janela.corCartao; border.width: 2; border.color: "#6a77ee" }
                // O foco só pega depois que o campo entra de fato na janela, por isso o callLater.
                Component.onCompleted: Qt.callLater(function() {
                    campoLateral.forceActiveFocus()
                    campoLateral.selectAll()
                })
                onAccepted: concluir(true)
                // Clicar fora confirma o nome. Só vale depois de o campo ter tido o foco.
                onActiveFocusChanged: {
                    if (activeFocus)
                        teveFoco = true
                    else if (teveFoco)
                        concluir(true)
                }
                Keys.onEscapePressed: concluir(false)
            }
        }
        Image {
            visible: linhaLateral.ejetavel && !linhaLateral.editando
            anchors.right: parent.right
            anchors.rightMargin: 9
            anchors.verticalCenter: parent.verticalCenter
            source: pastaIcones + "player-eject-cinza.svg"
            sourceSize.width: 16
            sourceSize.height: 16
            MouseArea {
                anchors.fill: parent
                anchors.margins: -5
                cursorShape: Qt.PointingHandCursor
                onClicked: linhaLateral.ejetar()
            }
        }
        DropArea {
            id: soltaLateral
            anchors.fill: parent
            enabled: linhaLateral.destino !== "" && linhaLateral.destino !== "recentes:"
            onDropped: (drop) => {
                if (drop.hasUrls) {
                    arquivos.soltar(drop.urls, linhaLateral.destino)
                    drop.accept()
                }
            }
        }
    }

    component TituloLateral: Texto {
        x: 10
        height: 26
        verticalAlignment: Text.AlignBottom
        bottomPadding: 5
        font.pixelSize: 11
        font.weight: Font.DemiBold
        color: janela.corTextoFraco
    }

    // Cliques, seleção e arrastar de um item da grade ou da lista.
    // As peças declaradas aqui não enxergam a janela pelo nome: recebem em "raiz".
    // Fundo de uma visão (grade ou lista): clique no vazio limpa a seleção, e o botão
    // direito abre o menu da pasta. A visão engole o clique esquerdo e não o repassa
    // para o que está atrás dela. Por isso o fundo fica dentro da área que rola,
    // junto dos itens e abaixo deles, e acompanha a rolagem para cobrir a parte visível.
    component FundoDaVisao: MouseArea {
        id: fundoDaVisao
        property Flickable visao
        parent: visao.contentItem
        x: visao.contentX
        y: visao.contentY
        z: 0          // os itens da visão ficam em z 1
        width: visao.width
        height: visao.height
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: (mouse) => janela.cliqueNoVazio(fundoDaVisao, mouse)
    }

    component Toque: MouseArea {
        id: toque
        property var raiz
        property var item
        property int indice: 0
        property bool recemMarcado: false
        // Partes da célula que contam como o item, em retângulos. Vazio: a célula toda.
        // Na grade são só o ícone e o nome: o clique no espaço entre dois itens cai
        // no fundo e tira a seleção, em vez de marcar o vizinho.
        property var zonas: []
        readonly property bool marcado: raiz.selecao.indexOf(item.caminho) >= 0
        anchors.fill: parent
        containmentMask: QtObject {
            function contains(ponto: point): bool {
                if (toque.zonas.length === 0)
                    return ponto.x >= 0 && ponto.y >= 0 && ponto.x < toque.width && ponto.y < toque.height
                for (let i = 0; i < toque.zonas.length; i++) {
                    const z = toque.zonas[i]
                    if (ponto.x >= z.x && ponto.x < z.x + z.width && ponto.y >= z.y && ponto.y < z.y + z.height)
                        return true
                }
                return false
            }
        }
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        drag.target: raiz.caminho === "lixeira:" ? null : alca
        drag.threshold: 12
        onPressed: (mouse) => {
            raiz.focar()
            if (mouse.button === Qt.RightButton) {
                if (!marcado) {
                    raiz.selecao = [item.caminho]
                    raiz.ancora = indice
                }
                const p = mapToItem(raiz.contentItem, mouse.x, mouse.y)
                raiz.abrirMenu(raiz.menuDeItem(), p.x - raiz.margem, p.y - raiz.margem)
            } else if (!marcado || (mouse.modifiers & (Qt.ControlModifier | Qt.ShiftModifier))) {
                raiz.clicar(indice, mouse.modifiers)
                recemMarcado = true
            } else {
                recemMarcado = false
            }
        }
        onClicked: (mouse) => {
            // Clique simples num item de uma seleção de vários: fica só ele.
            if (mouse.button === Qt.LeftButton && !recemMarcado
                    && !(mouse.modifiers & (Qt.ControlModifier | Qt.ShiftModifier))) {
                raiz.selecao = [item.caminho]
                raiz.ancora = indice
            }
        }
        onDoubleClicked: (mouse) => { if (mouse.button === Qt.LeftButton) raiz.abrirItem(item) }
        // O arrasto começa por aqui, e não por uma ligação direta, que entraria em laço.
        drag.onActiveChanged: if (drag.active) alca.Drag.active = true
        Item {
            id: alca
            Drag.dragType: Drag.Automatic
            Drag.supportedActions: Qt.MoveAction | Qt.CopyAction
            Drag.mimeData: ({ "text/uri-list": toque.raiz.textoArrasto })
            Drag.imageSource: toque.item.miniatura === "" ? "image://icone/" + toque.item.icone : ""
            Drag.onDragFinished: { alca.Drag.active = false; alca.x = 0; alca.y = 0 }
        }
    }

    // Campo para trocar o nome, no lugar do texto.
    component CampoNome: TextField {
        id: campoNome
        property var raiz
        property var item
        text: item.nome
        font.family: "Inter"
        font.pixelSize: 12
        color: janela.corTexto
        selectionColor: janela.corSelecaoTexto
        selectedTextColor: janela.corTexto
        selectByMouse: true
        topPadding: 4
        bottomPadding: 4
        leftPadding: 6
        rightPadding: 6
        background: Rectangle { radius: 7; color: janela.corCartao; border.width: 2; border.color: "#6a77ee" }
        property bool teveFoco: false
        // O foco só pega depois que o campo entra de fato na janela, por isso o callLater.
        Component.onCompleted: Qt.callLater(function() {
            campoNome.forceActiveFocus()
            const ponto = campoNome.item.pasta ? -1 : campoNome.text.lastIndexOf(".")
            campoNome.select(0, ponto > 0 ? ponto : campoNome.text.length)
        })
        onAccepted: raiz.concluirRenomear(item.caminho, text)
        // Clicar fora confirma o nome, como no Finder. Só vale depois de o campo ter tido o foco.
        onActiveFocusChanged: {
            if (activeFocus)
                teveFoco = true
            else if (teveFoco)
                raiz.concluirRenomear(item.caminho, text)
        }
        Keys.onEscapePressed: { raiz.renomeando = ""; raiz.focar() }
    }

    // Faixa invisível na beira da janela, para mudar o tamanho arrastando.
    component Beira: MouseArea {
        property var raiz
        property int lados: 0
        enabled: !raiz.cheia
        hoverEnabled: true
        onPressed: raiz.startSystemResize(lados)
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
            visible: !janela.cheia
            radius: janela.raio
            blur: 48
            spread: -6
            offset.y: 14
            color: Qt.rgba(0.16, 0.13, 0.35, 0.28)
        }

        // Fundo da janela, que é a cor da barra lateral. Um app fora do Plasma não
        // consegue pedir o desfoque do que está atrás, então o fundo é opaco.
        Rectangle {
            anchors.fill: parent
            radius: janela.raio
            gradient: Gradient {
                GradientStop { position: 0.0; color: janela.corLateralCima }
                GradientStop { position: 1.0; color: janela.corLateralBaixo }
            }
        }

        // Área dos arquivos: mais clara, com os cantos da direita arredondados.
        Item {
            x: janela.lateral
            width: parent.width - janela.lateral
            height: parent.height
            clip: true
            Rectangle {
                x: -30
                width: parent.width + 30
                height: parent.height
                radius: janela.raio
                color: janela.corConteudo
            }
        }
        Rectangle {
            anchors.fill: parent
            radius: janela.raio
            color: "transparent"
            border.width: janela.cheia ? 0 : 1
            border.color: janela.brilho(0.95)
        }
        Rectangle { x: janela.lateral; width: 1; height: parent.height; color: janela.brilho(0.8) }

        // Arrastar pelo topo ou pela barra lateral move a janela; dois cliques maximizam.
        MouseArea {
            width: parent.width
            height: 58
            onPressed: janela.startSystemMove()
            onDoubleClicked: janela.cheia ? janela.showNormal() : janela.showMaximized()
        }
        MouseArea {
            width: janela.lateral
            height: parent.height
            onPressed: janela.startSystemMove()
        }

        BotoesDaJanela {
            x: 18
            y: 19
            alvo: janela
            onFechar: janela.esconder()
        }

        // ---------------- barra lateral ----------------

        Flickable {
            x: 12
            y: 54
            width: janela.lateral - 24
            height: parent.height - 54 - 12
            contentHeight: colunaLateral.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            // Botão direito no vazio da barra lateral: desfazer a arrumação.
            MouseArea {
                width: parent.width
                height: Math.max(colunaLateral.height, parent.parent.height)
                acceptedButtons: Qt.RightButton
                onClicked: (mouse) => {
                    const p = mapToItem(painel, mouse.x, mouse.y)
                    janela.abrirMenu([{ id: "latRestaurar", nome: "Restaurar a barra lateral", icone: "restore" }], p.x, p.y)
                }
            }
            Column {
                id: colunaLateral
                width: parent.width
                spacing: 2
                TituloLateral { text: "Favoritos" }
                Repeater {
                    model: janela.favoritos
                    delegate: Entrada {
                        required property var modelData
                        required property int index
                        nome: modelData.nome
                        icone: modelData.icone
                        destino: modelData.caminho
                        grupo: "favoritos"
                        chave: modelData.chave
                        indice: index
                        total: janela.favoritos.length
                        atual: janela.caminho === modelData.caminho
                        onClicado: janela.ir(modelData.caminho)
                        onMovido: (para) => arquivos.moverNaLateral("favoritos", modelData.chave, para)
                        onRenomeado: (texto) => arquivos.renomearNaLateral(modelData.chave, texto)
                        onMenuPedido: (px, py) => {
                            const p = mapToItem(painel, px, py)
                            janela.alvoLateral = { grupo: "favoritos", item: modelData }
                            janela.abrirMenu(janela.menuDaLateral(modelData, "favoritos"), p.x, p.y)
                        }
                    }
                }
                Item { width: 1; height: 8 }
                TituloLateral { text: "Locais" }
                Repeater {
                    model: janela.locais
                    delegate: Entrada {
                        required property var modelData
                        required property int index
                        nome: modelData.nome
                        icone: modelData.icone
                        destino: modelData.caminho
                        grupo: "locais"
                        chave: modelData.chave
                        indice: index
                        total: janela.locais.length
                        atual: modelData.caminho !== "" && janela.caminho === modelData.caminho
                        ejetavel: modelData.removivel && modelData.montado
                        onClicado: janela.abrirLocal(modelData)
                        onEjetar: arquivos.ejetar(modelData.dispositivo)
                        onMovido: (para) => arquivos.moverNaLateral("locais", modelData.chave, para)
                        onRenomeado: (texto) => arquivos.renomearNaLateral(modelData.chave, texto)
                        onMenuPedido: (px, py) => {
                            const p = mapToItem(painel, px, py)
                            janela.alvoLateral = { grupo: "locais", item: modelData }
                            janela.alvoMenu = modelData.dispositivo
                            janela.abrirMenu(janela.menuDaLateral(modelData, "locais"), p.x, p.y)
                        }
                    }
                }
            }
        }

        // ---------------- barra de ferramentas ----------------

        Row {
            x: janela.lateral + 18
            y: 14
            spacing: 8
            Circulo {
                tamanho: 30
                nome: "chevron-left"
                dica: "Voltar"
                opacity: janela.posicao > 0 ? 1 : janela.apagado
                onClicado: janela.voltar()
            }
            Circulo {
                tamanho: 30
                nome: "chevron-right"
                dica: "Avançar"
                opacity: janela.posicao < janela.historico.length - 1 ? 1 : janela.apagado
                onClicado: janela.avancar()
            }
            Texto {
                leftPadding: 8
                height: 30
                width: Math.max(60, painel.width - janela.lateral - 18 - 76 - ferramentas.width - 36)
                verticalAlignment: Text.AlignVCenter
                text: janela.dados.nome
                font.pixelSize: 17
                font.weight: Font.DemiBold
            }
        }
        Row {
            id: ferramentas
            anchors.right: parent.right
            anchors.rightMargin: 18
            y: 13
            spacing: 10
            Botao {
                visible: janela.caminho === "lixeira:" && janela.itens.length > 0
                principal: false
                implicitHeight: 32
                text: "Esvaziar"
                onClicked: arquivos.esvaziarLixeira()
            }
            // Grade ou lista.
            Rectangle {
                width: 72
                height: 32
                radius: 10
                color: janela.linha(0.12)
                Row {
                    x: 3
                    y: 3
                    Repeater {
                        model: [{ id: "icones", icone: "layout-grid" }, { id: "lista", icone: "list" }]
                        delegate: Rectangle {
                            required property var modelData
                            width: 33
                            height: 26
                            radius: 8
                            color: janela.modo === modelData.id ? janela.brilho(1) : "transparent"
                            Image {
                                anchors.centerIn: parent
                                source: pastaIcones + parent.modelData.icone + (janela.modo === parent.modelData.id ? janela.iconeForte : "-cinza.svg")
                                sourceSize.width: 16
                                sourceSize.height: 16
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: janela.modo = parent.modelData.id
                            }
                        }
                    }
                }
            }
            Circulo {
                visible: !janela.especial
                tamanho: 32
                nome: "folder-plus"
                dica: "Nova pasta"
                opacity: janela.dados.gravavel ? 1 : janela.apagado
                onClicado: janela.novaPasta()
            }
            // Busca dentro da pasta.
            Rectangle {
                width: 190
                height: 32
                radius: 16
                color: janela.brilho(campoBusca.activeFocus ? 1 : 0.75)
                border.width: 1
                border.color: campoBusca.activeFocus ? "#8f99f2" : janela.linha(0.18)
                Image {
                    x: 11
                    anchors.verticalCenter: parent.verticalCenter
                    source: pastaIcones + "search-cinza.svg"
                    sourceSize.width: 15
                    sourceSize.height: 15
                }
                TextField {
                    id: campoBusca
                    x: 30
                    width: parent.width - 40
                    height: parent.height
                    placeholderText: "Buscar nesta pasta"
                    placeholderTextColor: janela.corTextoFraco
                    font.family: "Inter"
                    font.pixelSize: 13
                    color: janela.corTexto
                    selectByMouse: true
                    leftPadding: 2
                    verticalAlignment: TextInput.AlignVCenter
                    background: Item { }
                    onTextChanged: { janela.filtro = text; janela.filtrar(true) }
                    Keys.onEscapePressed: { text = ""; conteudo.forceActiveFocus() }
                    onAccepted: conteudo.forceActiveFocus()
                }
            }
        }

        // ---------------- arquivos ----------------

        FocusScope {
            id: conteudo
            x: janela.lateral + 1
            y: 58
            width: parent.width - janela.lateral - 1
            height: parent.height - 58 - 38
            focus: true

            Keys.onPressed: (event) => {
                const ctrl = event.modifiers & Qt.ControlModifier
                const alt = event.modifiers & Qt.AltModifier
                const comum = !janela.especial
                let usado = true
                if (alt && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                    if (comum) janela.executar("propriedades")
                } else if (ctrl && alt && event.key === Qt.Key_C) {
                    if (comum) janela.executar("copiarLocal")
                } else if (ctrl && event.key === Qt.Key_D) {
                    if (janela.selecao.length > 0 && comum) janela.executar("duplicar")
                } else if (ctrl && !(event.modifiers & Qt.ShiftModifier) && event.key === Qt.Key_N) {
                    if (comum) janela.executar("novajanela")
                } else if (event.key === Qt.Key_F5) {
                    janela.recarregar()
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (janela.selecao.length > 0) janela.executar("abrir")
                } else if (event.key === Qt.Key_F2) {
                    if (janela.selecao.length === 1 && comum) janela.executar("renomear")
                } else if (event.key === Qt.Key_Delete) {
                    if (janela.selecao.length > 0 && janela.caminho !== "lixeira:") janela.executar("lixeira")
                } else if (event.key === Qt.Key_Backspace || (alt && event.key === Qt.Key_Up)) {
                    janela.subir()
                } else if (alt && event.key === Qt.Key_Left) {
                    janela.voltar()
                } else if (alt && event.key === Qt.Key_Right) {
                    janela.avancar()
                } else if (ctrl && event.key === Qt.Key_A) {
                    janela.executar("tudo")
                } else if (ctrl && event.key === Qt.Key_C) {
                    if (janela.selecao.length > 0 && janela.caminho !== "lixeira:") janela.executar("copiar")
                } else if (ctrl && event.key === Qt.Key_X) {
                    if (janela.selecao.length > 0 && comum) janela.executar("recortar")
                } else if (ctrl && event.key === Qt.Key_V) {
                    if (comum) janela.executar("colar")
                } else if (ctrl && (event.modifiers & Qt.ShiftModifier) && event.key === Qt.Key_N) {
                    janela.novaPasta()
                } else if (ctrl && event.key === Qt.Key_H) {
                    janela.executar("ocultos")
                } else if (event.key === Qt.Key_Space) {
                    if (janela.espiando) janela.espiando = false
                    else janela.espiar()
                } else if (event.key === Qt.Key_Escape) {
                    if (janela.espiando) janela.espiando = false
                    else janela.selecao = []
                } else if (event.key === Qt.Key_Right) {
                    janela.andar(1)
                } else if (event.key === Qt.Key_Left) {
                    janela.andar(-1)
                } else if (event.key === Qt.Key_Down) {
                    janela.andar(janela.modo === "icones" ? Math.max(1, Math.floor(grade.width / grade.cellWidth)) : 1)
                } else if (event.key === Qt.Key_Up) {
                    janela.andar(janela.modo === "icones" ? -Math.max(1, Math.floor(grade.width / grade.cellWidth)) : -1)
                } else {
                    usado = false
                }
                event.accepted = usado
            }

            // Fundo: clique limpa a seleção, botão direito abre o menu da pasta,
            // e soltar arquivos aqui (até de outro app) copia para esta pasta.
            MouseArea {
                id: fundoGeral
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onPressed: (mouse) => janela.cliqueNoVazio(fundoGeral, mouse)
            }
            DropArea {
                anchors.fill: parent
                enabled: !janela.especial
                onDropped: (drop) => {
                    if (drop.hasUrls) {
                        arquivos.soltar(drop.urls, janela.caminho)
                        drop.accept()
                    }
                }
            }

            // Grade de ícones.
            GridView {
                id: grade
                visible: janela.modo === "icones"
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 6
                anchors.topMargin: 4
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                cellWidth: Math.floor(width / Math.max(1, Math.floor(width / (janela.tamanho + 62))))
                cellHeight: janela.tamanho + 62
                // Só a visão em uso recebe os itens: as duas ao mesmo tempo criariam dois
                // campos de nome para o mesmo arquivo, um tirando o foco do outro.
                model: janela.modo === "icones" ? janela.itens : []
                interactive: true
                ScrollBar.vertical: ScrollBar { }
                FundoDaVisao { visao: grade }
                delegate: Item {
                    id: celula
                    required property var modelData
                    required property int index
                    readonly property bool marcado: janela.selecao.indexOf(modelData.caminho) >= 0 || soltaCelula.containsDrag
                    readonly property bool editando: janela.renomeando === modelData.caminho
                    width: grade.cellWidth
                    height: grade.cellHeight
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 4
                        width: janela.tamanho + 20
                        height: janela.tamanho + 14
                        radius: 12
                        color: janela.linha(celula.marcado ? 0.16 : 0)
                    }
                    Image {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 11
                        width: janela.tamanho
                        height: janela.tamanho
                        source: celula.modelData.miniatura !== "" ? celula.modelData.miniatura
                                                                   : "image://icone/" + celula.modelData.icone
                        sourceSize.width: 256
                        sourceSize.height: 256
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        opacity: celula.modelData.oculto ? 0.55 : 1
                    }
                    Rectangle {
                        visible: celula.marcado && !celula.editando
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: nomeCelula.y - 1
                        width: Math.min(nomeCelula.contentWidth + 12, parent.width - 4)
                        height: nomeCelula.contentHeight + 3
                        radius: 6
                        color: "#5f6ce5"
                    }
                    Texto {
                        id: nomeCelula
                        visible: !celula.editando
                        x: 6
                        y: janela.tamanho + 24
                        width: parent.width - 12
                        text: celula.modelData.nome
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        color: celula.marcado ? "#ffffff" : janela.corTexto
                    }
                    Toque {
                        raiz: janela
                        item: celula.modelData
                        indice: celula.index
                        // O quadro do ícone e a faixa do nome, com uma folga pequena em volta do nome.
                        readonly property real larguraDoNome: Math.min(nomeCelula.contentWidth + 12, celula.width - 4)
                        zonas: [
                            Qt.rect((celula.width - janela.tamanho - 20) / 2, 4, janela.tamanho + 20, janela.tamanho + 14),
                            Qt.rect((celula.width - larguraDoNome) / 2, nomeCelula.y - 1, larguraDoNome, nomeCelula.contentHeight + 3)
                        ]
                    }
                    DropArea {
                        id: soltaCelula
                        anchors.fill: parent
                        enabled: celula.modelData.pasta && !janela.especial
                        onDropped: (drop) => {
                            if (drop.hasUrls) {
                                arquivos.soltar(drop.urls, celula.modelData.caminho)
                                drop.accept()
                            }
                        }
                    }
                    Loader {
                        active: celula.editando
                        x: 4
                        y: nomeCelula.y - 4
                        width: parent.width - 8
                        sourceComponent: Component {
                            CampoNome { raiz: janela; item: celula.modelData; horizontalAlignment: TextInput.AlignHCenter }
                        }
                    }
                }
            }

            // Lista com colunas.
            Item {
                id: cabecalho
                visible: janela.modo === "lista"
                x: 14
                width: parent.width - 28
                height: 28
                Repeater {
                    model: [{ id: "nome", nome: "Nome" }, { id: "modificado", nome: "Modificado em" },
                            { id: "tamanho", nome: "Tamanho" }, { id: "tipo", nome: "Tipo" }]
                    delegate: Item {
                        required property var modelData
                        required property int index
                        x: [0, cabecalho.width - 440, cabecalho.width - 280, cabecalho.width - 170][index] + (index === 0 ? 40 : 0)
                        width: [cabecalho.width - 480, 150, 100, 170][index]
                        height: parent.height
                        Texto {
                            anchors.verticalCenter: parent.verticalCenter
                            text: parent.modelData.nome + (janela.ordem === parent.modelData.id ? (janela.crescente ? "  ↑" : "  ↓") : "")
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: janela.corTextoMedio
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (janela.ordem === parent.modelData.id) {
                                    janela.crescente = !janela.crescente
                                } else {
                                    janela.ordem = parent.modelData.id
                                    janela.crescente = true
                                }
                                janela.filtrar(true)
                            }
                        }
                    }
                }
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: janela.linha(0.12) }
            }
            ListView {
                id: lista2
                visible: janela.modo === "lista"
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                anchors.topMargin: 32
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: janela.modo === "lista" ? janela.itens : []
                ScrollBar.vertical: ScrollBar { }
                FundoDaVisao { visao: lista2 }
                delegate: Rectangle {
                    id: linha
                    required property var modelData
                    required property int index
                    readonly property bool marcado: janela.selecao.indexOf(modelData.caminho) >= 0 || soltaLinha.containsDrag
                    readonly property bool editando: janela.renomeando === modelData.caminho
                    readonly property color corTexto: marcado ? "#ffffff" : janela.corTexto
                    readonly property color corDetalhe: marcado ? "#e6e8ff" : janela.corTextoMedio
                    width: lista2.width
                    height: 32
                    radius: 8
                    color: marcado ? "#5f6ce5" : (index % 2 === 1 ? janela.linha(0.05) : "transparent")
                    Image {
                        x: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: 22
                        height: 22
                        source: linha.modelData.miniatura !== "" ? linha.modelData.miniatura
                                                                  : "image://icone/" + linha.modelData.icone
                        sourceSize.width: 64
                        sourceSize.height: 64
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        opacity: linha.modelData.oculto ? 0.55 : 1
                    }
                    Texto {
                        visible: !linha.editando
                        x: 40
                        width: parent.width - 480 - 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: linha.modelData.nome
                        font.pixelSize: 13
                        color: linha.corTexto
                    }
                    Texto {
                        x: parent.width - 440
                        width: 150
                        anchors.verticalCenter: parent.verticalCenter
                        text: linha.modelData.modificadoTexto
                        font.pixelSize: 12
                        color: linha.corDetalhe
                    }
                    Texto {
                        x: parent.width - 280
                        width: 100
                        anchors.verticalCenter: parent.verticalCenter
                        text: linha.modelData.tamanhoTexto
                        font.pixelSize: 12
                        color: linha.corDetalhe
                    }
                    Texto {
                        x: parent.width - 170
                        width: 164
                        anchors.verticalCenter: parent.verticalCenter
                        text: linha.modelData.tipo
                        font.pixelSize: 12
                        color: linha.corDetalhe
                    }
                    Toque { raiz: janela; item: linha.modelData; indice: linha.index }
                    DropArea {
                        id: soltaLinha
                        anchors.fill: parent
                        enabled: linha.modelData.pasta && !janela.especial
                        onDropped: (drop) => {
                            if (drop.hasUrls) {
                                arquivos.soltar(drop.urls, linha.modelData.caminho)
                                drop.accept()
                            }
                        }
                    }
                    Loader {
                        active: linha.editando
                        x: 34
                        y: 3
                        width: parent.width - 480 - 4
                        sourceComponent: Component { CampoNome { raiz: janela; item: linha.modelData; font.pixelSize: 13 } }
                    }
                }
            }

            // Pasta vazia.
            Texto {
                visible: janela.itens.length === 0
                anchors.centerIn: parent
                text: janela.filtro !== "" ? "Nada encontrado nesta pasta"
                      : (janela.caminho === "lixeira:" ? "A Lixeira está vazia"
                      : (janela.caminho === "recentes:" ? "Nenhum arquivo recente" : "Pasta vazia"))
                font.pixelSize: 15
                color: janela.corTextoFraco
            }
        }

        // ---------------- rodapé: caminho, contagem e tamanho dos ícones ----------------

        Rectangle {
            x: janela.lateral + 1
            y: parent.height - 38
            width: parent.width - janela.lateral - 1
            height: 1
            color: janela.linha(0.1)
        }
        Item {
            x: janela.lateral + 18
            y: parent.height - 37
            width: parent.width - janela.lateral - 36
            height: 36
            Row {
                id: trilha
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - direita.width - 16
                clip: true
                spacing: 2
                Repeater {
                    model: janela.dados.partes
                    delegate: Row {
                        required property var modelData
                        required property int index
                        spacing: 2
                        Image {
                            visible: parent.index > 0
                            anchors.verticalCenter: parent.verticalCenter
                            source: pastaIcones + "chevron-right-cinza.svg"
                            sourceSize.width: 12
                            sourceSize.height: 12
                        }
                        Texto {
                            text: parent.modelData.nome
                            font.pixelSize: 12
                            color: parent.index === janela.dados.partes.length - 1 ? janela.corTexto : janela.corTextoMedio
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: janela.ir(parent.parent.modelData.caminho)
                            }
                        }
                    }
                }
            }
            Row {
                id: direita
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 14
                Texto {
                    anchors.verticalCenter: parent.verticalCenter
                    text: janela.estadoTexto
                    font.pixelSize: 12
                    color: janela.corTextoMedio
                }
                Slider {
                    id: zoom
                    visible: janela.modo === "icones"
                    anchors.verticalCenter: parent.verticalCenter
                    width: 96
                    height: 20
                    from: 48
                    to: 128
                    stepSize: 8
                    value: janela.tamanho
                    onMoved: janela.tamanho = Math.round(value)
                    background: Rectangle {
                        x: zoom.leftPadding
                        y: zoom.topPadding + zoom.availableHeight / 2 - 2
                        width: zoom.availableWidth
                        height: 4
                        radius: 2
                        color: janela.linha(0.2)
                    }
                    handle: Rectangle {
                        x: zoom.leftPadding + zoom.visualPosition * (zoom.availableWidth - width)
                        y: zoom.topPadding + zoom.availableHeight / 2 - 7
                        width: 14
                        height: 14
                        radius: 7
                        color: "#ffffff"
                        border.width: 1
                        border.color: janela.linha(0.3)
                    }
                }
            }
        }

        // ---------------- cópia em andamento e avisos ----------------

        Rectangle {
            visible: arquivos.tarefa.ativa
            anchors.horizontalCenter: conteudo.horizontalCenter
            y: parent.height - 38 - height - 14
            width: 320
            height: 54
            radius: 14
            color: janela.corCartao
            border.width: 1
            border.color: janela.linha(0.16)
            Texto {
                x: 16
                y: 10
                width: parent.width - 32
                text: arquivos.tarefa.texto
                font.pixelSize: 12
                elide: Text.ElideMiddle
            }
            Rectangle {
                x: 16
                y: 34
                width: parent.width - 32
                height: 5
                radius: 2.5
                color: janela.linha(0.15)
                Rectangle {
                    width: Math.max(10, parent.width * arquivos.tarefa.fracao)
                    height: parent.height
                    radius: 2.5
                    color: "#6a77ee"
                }
            }
        }
        Rectangle {
            visible: janela.mensagem !== ""
            anchors.horizontalCenter: conteudo.horizontalCenter
            y: parent.height - 38 - height - 14
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

        // ---------------- pré-visualização (Espaço) ----------------
        // Imagem inteira, começo do texto ou os dados do arquivo. As setas trocam de
        // item com ela aberta; Espaço ou Esc fecham.

        Rectangle {
            visible: janela.espiando
            anchors.fill: parent
            radius: janela.raio
            color: Qt.rgba(0.16, 0.13, 0.35, 0.18)
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onPressed: { janela.espiando = false; conteudo.forceActiveFocus() }
            }
        }
        Rectangle {
            id: espia
            readonly property var d: janela.espiada
            visible: janela.espiando
            anchors.centerIn: parent
            width: Math.min(parent.width - 96, 760)
            height: Math.min(parent.height - 80, 540)
            radius: 18
            color: janela.corConteudo
            border.width: 1
            border.color: janela.linha(0.2)
            MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

            Texto {
                x: 22
                y: 16
                width: parent.width - 44 - 120
                text: espia.d.nome || ""
                font.pixelSize: 16
                font.weight: Font.DemiBold
                elide: Text.ElideMiddle
            }
            Texto {
                x: 22
                y: 40
                width: parent.width - 44 - 120
                text: [espia.d.tipo, espia.d.tamanho, espia.d.modificado].filter(t => t && t !== "—").join("  ·  ")
                font.pixelSize: 12
                color: janela.corTextoMedio
            }
            Botao {
                x: parent.width - width - 18
                y: 16
                text: "Abrir"
                onClicked: {
                    const item = janela.itens.find(i => i.caminho === espia.d.caminho)
                    janela.espiando = false
                    janela.focar()
                    if (item) janela.abrirItem(item)
                }
            }
            Rectangle {
                x: 0
                y: 68
                width: parent.width
                height: 1
                color: janela.linha(0.14)
            }
            Item {
                x: 18
                y: 80
                width: parent.width - 36
                height: parent.height - 80 - 18
                clip: true
                Image {
                    visible: espia.d.classe === "imagem"
                    anchors.fill: parent
                    source: visible ? espia.d.imagem : ""
                    sourceSize.width: 1520
                    sourceSize.height: 1080
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    smooth: true
                }
                Flickable {
                    visible: espia.d.classe === "texto"
                    anchors.fill: parent
                    contentWidth: width
                    contentHeight: trecho.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollIndicator.vertical: ScrollIndicator { }
                    Text {
                        id: trecho
                        width: parent.width
                        text: espia.d.texto || ""
                        textFormat: Text.PlainText
                        font.family: "monospace"
                        font.pixelSize: 12
                        color: janela.corTextoPrevia
                        wrapMode: Text.WrapAnywhere
                    }
                }
                Column {
                    visible: espia.d.classe === "outro"
                    anchors.centerIn: parent
                    spacing: 14
                    Image {
                        anchors.horizontalCenter: parent.horizontalCenter
                        source: visible && espia.d.icone ? "image://icone/" + espia.d.icone : ""
                        sourceSize.width: 160
                        sourceSize.height: 160
                        width: 160
                        height: 160
                    }
                    Texto {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: espia.d.pasta ? "Pasta com " + espia.d.tamanho : "Sem pré-visualização para este tipo de arquivo"
                        font.pixelSize: 13
                        color: janela.corTextoMedio
                    }
                }
            }
        }

        // ---------------- menu do botão direito ----------------

        // O menu e o submenu são janelas à parte: assim passam da borda da janela do
        // Arquivos e ficam por cima da dock, e o sistema os mantém dentro da tela.
        // O submenu abre ao lado quando o mouse para numa entrada com seta.
        component CartaoDoMenu: Rectangle {
            radius: 12
            color: janela.corCartao
            border.width: 1
            border.color: janela.linha(0.18)
            Rectangle {
                z: -1
                anchors.fill: parent
                anchors.margins: -1
                anchors.topMargin: 3
                anchors.bottomMargin: -6
                radius: 14
                color: Qt.rgba(0.16, 0.13, 0.35, 0.09)
            }
            // Cliques no cartão não fecham o menu.
            MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }
        }

        component LinhaDoMenu: Item {
            id: linhaMenu
            property var dados: ({})
            property bool realce: false          // sob o mouse, ou com o submenu aberto
            readonly property bool separador: dados.separador === true
            readonly property bool inativa: dados.inativa === true
            readonly property bool temSub: dados.filhos !== undefined || dados.apps === true
            readonly property bool forte: realce && !inativa
            signal entrou()
            signal clicado()
            width: menu.largura - 12
            height: separador ? 9 : 30

            Rectangle {
                visible: linhaMenu.separador
                x: 8
                y: 4
                width: parent.width - 16
                height: 1
                color: janela.linha(0.14)
            }
            Rectangle {
                visible: !linhaMenu.separador
                anchors.fill: parent
                radius: 8
                color: linhaMenu.forte ? "#5f6ce5" : "transparent"
                // Ícone de traço, ou o ícone do tema (apps e cores de pasta).
                Image {
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    visible: linhaMenu.dados.icone !== undefined
                    source: visible ? pastaIcones + linhaMenu.dados.icone
                                      + (linhaMenu.forte || janela.escuro ? "-branco.svg" : "-cinza.svg") : ""
                    sourceSize.width: 16
                    sourceSize.height: 16
                    opacity: linhaMenu.forte || !janela.escuro ? 1 : 0.7
                }
                Image {
                    x: 9
                    anchors.verticalCenter: parent.verticalCenter
                    visible: linhaMenu.dados.tema !== undefined && linhaMenu.dados.tema !== ""
                    source: visible ? "image://icone/" + linhaMenu.dados.tema : ""
                    width: 18
                    height: 18
                    sourceSize.width: 36
                    sourceSize.height: 36
                }
                Texto {
                    x: linhaMenu.dados.icone === undefined && (linhaMenu.dados.tema === undefined || linhaMenu.dados.tema === "") ? 12 : 36
                    width: parent.width - x - direita.width - 18
                    anchors.verticalCenter: parent.verticalCenter
                    text: linhaMenu.separador ? "" : linhaMenu.dados.nome
                    font.pixelSize: 13
                    color: linhaMenu.forte ? "#ffffff" : (linhaMenu.inativa ? janela.corTextoFraco : janela.corTexto)
                }
                Row {
                    id: direita
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Texto {
                        visible: linhaMenu.dados.atalho !== undefined
                        text: linhaMenu.dados.atalho || ""
                        font.pixelSize: 12
                        color: linhaMenu.forte ? Qt.rgba(1, 1, 1, 0.8) : janela.corTextoFraco
                    }
                    Image {
                        visible: linhaMenu.dados.marcado === true
                        source: pastaIcones + "check" + (linhaMenu.forte || janela.escuro ? "-branco.svg" : "-escuro.svg")
                        sourceSize.width: 14
                        sourceSize.height: 14
                    }
                    Image {
                        visible: linhaMenu.temSub
                        source: pastaIcones + "chevron-right" + (linhaMenu.forte ? "-branco.svg" : "-cinza.svg")
                        sourceSize.width: 14
                        sourceSize.height: 14
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: linhaMenu.entrou()
                    onClicked: if (!linhaMenu.inativa) linhaMenu.clicado()
                }
            }
        }

        Window {
            id: menu
            property var entradas: []
            property int aberta: -1           // entrada cujo submenu está aberto
            property int sobre: -1            // entrada sob o mouse
            readonly property int largura: 272
            readonly property int encaixe: 6  // o submenu entra um pouco por cima do menu
            readonly property int folga: 8    // faixa em volta do cartão, para a sombra dele

            function open() { visible = true }
            function close() { visible = false }
            function abrirSub(indice) {
                const dados = entradas[indice]
                if (!dados || (dados.filhos === undefined && dados.apps !== true)) {
                    submenu.visible = false
                    return
                }
                if (aberta === indice && submenu.visible)
                    return
                submenu.visible = false
                submenu.entradas = dados.filhos !== undefined ? dados.filhos : janela.appsDoMarcado()
                // Ao lado do menu, na altura da entrada que o abriu.
                const linha = linhasDoMenu.itemAt(indice)
                submenu.x = menu.x + largura - encaixe
                submenu.y = menu.y + (linha ? linha.y : 0)
                aberta = indice
                submenu.visible = true
            }

            // Janela do tipo "dica": aparece na posição pedida sem tomar o teclado nem
            // capturar o mouse. Quem fecha o menu é a própria tela do Arquivos: clique em
            // qualquer outro lugar, Esc, ou a janela perder o foco.
            flags: Qt.ToolTip | Qt.FramelessWindowHint
            transientParent: janela
            color: "transparent"
            width: largura + 2 * folga
            height: colunaMenu.height + 12 + 2 * folga
            onVisibleChanged: {
                if (visible)
                    return
                esperaAbrir.stop()
                esperaFechar.stop()
                submenu.visible = false
                sobre = -1
            }

            // Parar o mouse numa entrada com seta abre o submenu dela. Sair para outra
            // entrada fecha, com uma espera curta para dar tempo de o mouse chegar ao submenu.
            Timer { id: esperaAbrir; interval: 140; onTriggered: menu.abrirSub(menu.sobre) }
            Timer { id: esperaFechar; interval: 280; onTriggered: if (!sobreSub.hovered) menu.abrirSub(menu.sobre) }

            CartaoDoMenu {
                x: menu.folga
                y: menu.folga
                width: menu.largura
                height: colunaMenu.height + 12
                Column {
                    id: colunaMenu
                    x: 6
                    y: 6
                    Repeater {
                        id: linhasDoMenu
                        model: menu.entradas
                        delegate: LinhaDoMenu {
                            required property var modelData
                            required property int index
                            dados: modelData
                            realce: menu.sobre === index || (menu.aberta === index && submenu.visible)
                            onEntrou: {
                                menu.sobre = index
                                if (temSub) {
                                    esperaFechar.stop()
                                    esperaAbrir.restart()
                                } else {
                                    esperaAbrir.stop()
                                    if (submenu.visible)
                                        esperaFechar.restart()
                                }
                            }
                            onClicado: {
                                if (temSub) {
                                    esperaAbrir.stop()
                                    menu.abrirSub(index)
                                } else {
                                    menu.close()
                                    janela.executar(modelData.id)
                                }
                            }
                        }
                    }
                }
                HoverHandler { onHoveredChanged: if (!hovered) menu.sobre = -1 }
            }

            // O submenu é uma janela filha do menu, para o sistema posicioná-lo ao lado dele.
            Window {
                id: submenu
                property var entradas: []
                property int sobre: -1
                flags: Qt.ToolTip | Qt.FramelessWindowHint
                transientParent: menu
                color: "transparent"
                width: menu.largura + 2 * menu.folga
                height: colunaSub.height + 12 + 2 * menu.folga
                onVisibleChanged: {
                    if (!visible) {
                        menu.aberta = -1
                        sobre = -1
                    }
                }

                CartaoDoMenu {
                    x: menu.folga
                    y: menu.folga
                    width: menu.largura
                    height: colunaSub.height + 12
                    Column {
                        id: colunaSub
                        x: 6
                        y: 6
                        Repeater {
                            model: submenu.entradas
                            delegate: LinhaDoMenu {
                                required property var modelData
                                required property int index
                                dados: modelData
                                realce: submenu.sobre === index
                                onEntrou: {
                                    submenu.sobre = index
                                    esperaFechar.stop()
                                }
                                onClicado: {
                                    menu.close()
                                    janela.executar(modelData.id)
                                }
                            }
                        }
                    }
                    HoverHandler { id: sobreSub; onHoveredChanged: if (!hovered) submenu.sobre = -1 }
                }
            }
        }

        // ---------------- beiras para mudar o tamanho ----------------

        Beira { raiz: janela; x: -5; y: 14; width: 9; height: parent.height - 28; lados: Qt.LeftEdge; cursorShape: Qt.SizeHorCursor }
        Beira { raiz: janela; x: parent.width - 4; y: 14; width: 9; height: parent.height - 28; lados: Qt.RightEdge; cursorShape: Qt.SizeHorCursor }
        Beira { raiz: janela; x: 14; y: -5; width: parent.width - 28; height: 9; lados: Qt.TopEdge; cursorShape: Qt.SizeVerCursor }
        Beira { raiz: janela; x: 14; y: parent.height - 4; width: parent.width - 28; height: 9; lados: Qt.BottomEdge; cursorShape: Qt.SizeVerCursor }
        Beira { raiz: janela; x: -5; y: -5; width: 19; height: 19; lados: Qt.LeftEdge | Qt.TopEdge; cursorShape: Qt.SizeFDiagCursor }
        Beira { raiz: janela; x: parent.width - 14; y: -5; width: 19; height: 19; lados: Qt.RightEdge | Qt.TopEdge; cursorShape: Qt.SizeBDiagCursor }
        Beira { raiz: janela; x: -5; y: parent.height - 14; width: 19; height: 19; lados: Qt.LeftEdge | Qt.BottomEdge; cursorShape: Qt.SizeBDiagCursor }
        Beira { raiz: janela; x: parent.width - 14; y: parent.height - 14; width: 19; height: 19; lados: Qt.RightEdge | Qt.BottomEdge; cursorShape: Qt.SizeFDiagCursor }
    }
}
