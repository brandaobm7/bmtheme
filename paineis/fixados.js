// Devolve ao instalador os apps fixados na barra de tarefas atual, separados por vírgula.
var achados = [];
var paineis = panels();
for (var i = 0; i < paineis.length; i++) {
    var itens = paineis[i].widgets();
    for (var j = 0; j < itens.length; j++) {
        if (itens[j].type === "org.kde.plasma.icontasks" || itens[j].type === "org.kde.plasma.taskmanager") {
            itens[j].currentConfigGroup = ["General"];
            var valor = itens[j].readConfig("launchers", "");
            if (valor) {
                achados.push(String(valor));
            }
        }
    }
}
print(achados.join(","));
