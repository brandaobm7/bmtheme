// Nome do app em uso, na barra superior. Sem app aberto, a cápsula some.
//
// Este widget também atende a tecla Windows. No Plasma 6 ela chama o "lançador de
// aplicativos": o Plasma procura na barra um widget que se declare lançador
// (X-Plasma-Provides, no metadata.json) e o ativa. O botão "Todos os apps" não
// pode ser esse widget, porque a ativação dele já é do Alt+Espaço, que abre a
// busca. Então quem se declara é este, e ao ser ativado pede a grade de apps
// pelo mesmo comando do ícone Apps da dock.
import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.taskmanager as TaskManager

PlasmoidItem {
    id: raiz

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    property string nome: ""

    // Tecla Windows: abre ou fecha a grade de todos os apps.
    activationTogglesExpanded: false
    Plasmoid.onActivated: comando.connectSource("\"$HOME/.local/bin/bmos-apps\" # " + Date.now())
    P5Support.DataSource {
        id: comando
        engine: "executable"
        onNewData: (origem) => disconnectSource(origem)
    }

    function atualizar() {
        const ativa = tarefas.activeTask
        nome = ativa.valid ? (tarefas.data(ativa, TaskManager.AbstractTasksModel.AppName) || "") : ""
    }

    TaskManager.TasksModel {
        id: tarefas
        sortMode: TaskManager.TasksModel.SortDisabled
        groupMode: TaskManager.TasksModel.GroupDisabled
        onActiveTaskChanged: raiz.atualizar()
        onDataChanged: raiz.atualizar()
        onCountChanged: raiz.atualizar()
        Component.onCompleted: raiz.atualizar()
    }

    fullRepresentation: Capsula {
        vazia: raiz.nome === ""
        Text {
            text: raiz.nome
            color: parent.parent.corTexto
            font.family: "Inter"
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }
    }
}
