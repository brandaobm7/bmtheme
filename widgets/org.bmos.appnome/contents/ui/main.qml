// Nome do app em uso, na barra superior. Sem app aberto, a cápsula some.
import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.taskmanager as TaskManager

PlasmoidItem {
    id: raiz

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    property string nome: ""

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
