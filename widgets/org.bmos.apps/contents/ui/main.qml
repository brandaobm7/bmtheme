// Botão "Todos os apps" da barra superior do bmos.
// O clique abre a grade de apps em tela cheia. O atalho do widget (Alt+Espaço,
// posto pelo instalador) abre a busca.
import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support

PlasmoidItem {
    id: raiz

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    activationTogglesExpanded: false
    toolTipMainText: "Todos os apps"

    // Lista de apps, no formato que o ajudante devolve: nome, icone, caminho e termos.
    property var apps: []
    readonly property string ajudante: "python3 '" + Qt.resolvedUrl("../code/apps.py").toString().replace(/^file:\/\//, "") + "'"

    function lerApps() {
        leitor.connectSource(ajudante + " # " + Date.now())
    }
    function abrirApp(caminho) {
        lancador.connectSource("kioclient exec '" + caminho.replace(/'/g, "'\\''") + "' >/dev/null 2>&1 &")
    }

    Plasmoid.onActivated: busca.alternar()
    Component.onCompleted: lerApps()

    P5Support.DataSource {
        id: leitor
        engine: "executable"
        onNewData: (origem, dados) => {
            disconnectSource(origem)
            try {
                raiz.apps = JSON.parse(dados.stdout)
            } catch (erro) {
                // Resposta incompleta: fica com a lista anterior.
            }
        }
    }
    P5Support.DataSource {
        id: lancador
        engine: "executable"
        onNewData: (origem) => disconnectSource(origem)
    }

    fullRepresentation: Capsula {
        clicavel: true
        onClicado: grade.alternar()
        Icone {
            nome: "layout-grid"
            tamanho: 16
            color: parent.parent.corTexto
        }
    }

    Grade {
        id: grade
        apps: raiz.apps
        // A lista é lida de novo a cada abertura, para um app recém-instalado aparecer.
        onAberta: raiz.lerApps()
        onEscolhido: (caminho) => raiz.abrirApp(caminho)
    }
    Busca {
        id: busca
    }
}
