// Monta a barra superior e a dock do bmos. Roda dentro do Plasma, pelo instalador.
// Os painéis que existiam são removidos. A cópia deles fica guardada pelo
// instalador e volta na desinstalação.

// Guarda os apps fixados na barra de tarefas atual, para a dock nascer com os mesmos.
var fixados = "";
var antigos = panels();
for (var i = 0; i < antigos.length; i++) {
    var itens = antigos[i].widgets();
    for (var j = 0; j < itens.length; j++) {
        if (itens[j].type === "org.kde.plasma.icontasks" || itens[j].type === "org.kde.plasma.taskmanager") {
            itens[j].currentConfigGroup = ["General"];
            var valor = itens[j].readConfig("launchers", "");
            if (valor) {
                fixados = valor;
            }
        }
    }
}
for (var k = 0; k < antigos.length; k++) {
    antigos[k].remove();
}
// Ficam de fora os apps fixados que não existem neste computador. A lista vem do instalador.
if (typeof ausentes !== "undefined" && fixados) {
    fixados = String(fixados).split(",").filter(function (item) {
        return ausentes.indexOf(item.replace(/^applications:/, "")) < 0;
    }).join(",");
}

// Barra superior: transparente, com uma cápsula por widget.
var barra = new Panel;
barra.location = "top";
barra.height = 38;
barra.floating = false;
barra.hiding = "none";
barra.addWidget("org.bmos.apps");
barra.addWidget("org.bmos.appnome");
barra.addWidget("org.kde.plasma.panelspacer");
// A bandeja do sistema fica, porque é ela que mostra os avisos e os ícones dos
// apps (Steam, Discord). Saem dela os itens que a Central de Controle já cobre
// e a área de transferência, que continua no atalho Meta+V.
var bandeja = barra.addWidget("org.kde.plasma.systemtray");
var cobertos = ["org.kde.plasma.volume", "org.kde.plasma.networkmanagement", "org.kde.plasma.bluetooth",
                "org.kde.plasma.battery", "org.kde.plasma.brightness", "org.kde.plasma.clipboard"];
// No Plasma 6.4 a lista de itens fica no próprio widget da bandeja.
// Em versões anteriores, fica num contêiner à parte, apontado por SystrayContainmentId.
var contenedor = bandeja.readConfig("SystrayContainmentId", "");
var itensDaBandeja = contenedor ? desktopById(contenedor) : bandeja;
if (itensDaBandeja) {
    itensDaBandeja.currentConfigGroup = ["General"];
    var lista = function (chave) {
        var valor = itensDaBandeja.readConfig(chave, "");
        return valor ? String(valor).split(",") : [];
    };
    // Um item conhecido que não está entre os ligados fica desligado.
    // Os que a bandeja ainda não conhece ela mesma liga ao carregar.
    var ligados = lista("extraItems").filter(function (item) { return cobertos.indexOf(item) < 0; });
    var conhecidos = lista("knownItems").filter(function (item) { return cobertos.indexOf(item) < 0; }).concat(cobertos);
    itensDaBandeja.writeConfig("extraItems", ligados.join(","));
    itensDaBandeja.writeConfig("knownItems", conhecidos.join(","));
}
barra.addWidget("org.bmos.central");
barra.addWidget("org.bmos.relogio");

// Dock: flutuante, centralizada e do tamanho dos ícones.
var dock = new Panel;
dock.location = "bottom";
dock.height = 74;   // a mesma altura de ALTURA_DOCK em ferramentas/gerar-estilo.py
dock.alignment = "center";
dock.lengthMode = "fit";
dock.floating = true;
dock.hiding = "none";
var tarefas = dock.addWidget("org.kde.plasma.icontasks");
tarefas.currentConfigGroup = ["General"];
// O primeiro ícone da dock abre a grade de todos os apps.
fixados = "applications:org.bmos.grade.desktop" + (fixados ? "," + fixados : "");
// Na imagem que liga no modo jogo da Steam, o último ícone volta a ele.
if (typeof modoJogo !== "undefined" && modoJogo && fixados.indexOf("org.bmos.modojogo.desktop") < 0) {
    fixados += ",applications:org.bmos.modojogo.desktop";
}
tarefas.writeConfig("launchers", fixados);
tarefas.writeConfig("fill", false);
// O Plasma faz cada ícone ocupar um quadrado da altura da dock, mais os recuos dos
// lados vezes este número. Negativo, ele estreita o quadrado, e os ícones ficam
// próximos sem perder a folga em cima e embaixo. As contas estão em
// ferramentas/gerar-estilo.py (ESPACAMENTO_DOCK).
tarefas.writeConfig("iconSpacing", -4);
tarefas.writeConfig("indicateAudioStreams", false);

// Devolve o número da barra superior ao instalador, que termina de ajustá-la.
print(barra.id);
