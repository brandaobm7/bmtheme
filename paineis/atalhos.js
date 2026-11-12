// Põe a busca do bmos no Alt+Espaço. Roda dentro do Plasma, pelo instalador,
// em toda instalação. A busca mora no widget "Todos os apps": o atalho do widget abre a busca.
// Devolve o número do widget, que o desinstalador usa para soltar o atalho.
var paineis = panels();
var numero = "";
for (var i = 0; i < paineis.length; i++) {
    var itens = paineis[i].widgets();
    for (var j = 0; j < itens.length; j++) {
        if (itens[j].type === "org.bmos.apps") {
            // Limpar antes obriga o Plasma a registrar o atalho de novo.
            itens[j].globalShortcut = "";
            itens[j].globalShortcut = "Alt+Space";
            numero = itens[j].id;
        }
    }
}
print(numero);
