// Põe o ícone "Lixeira" no fim da dock de quem instalou o tema antes de ele existir.
var paineis = panels();
for (var i = 0; i < paineis.length; i++) {
    var itens = paineis[i].widgets();
    var temBarraDoTema = false;
    for (var j = 0; j < itens.length; j++) {
        if (itens[j].type.indexOf("org.bmos.") === 0) {
            temBarraDoTema = true;
        }
    }
    // A dock é o painel com a lista de apps e sem os widgets da barra superior.
    for (var k = 0; k < itens.length && !temBarraDoTema; k++) {
        if (itens[k].type === "org.kde.plasma.icontasks") {
            itens[k].currentConfigGroup = ["General"];
            var fixados = String(itens[k].readConfig("launchers", ""));
            if (fixados.indexOf("org.bmos.lixeira.desktop") < 0) {
                itens[k].writeConfig("launchers", (fixados ? fixados + "," : "") + "applications:org.bmos.lixeira.desktop");
            }
        }
    }
}
