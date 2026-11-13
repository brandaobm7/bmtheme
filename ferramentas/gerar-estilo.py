#!/usr/bin/env python3
"""Gera o estilo do Plasma do bmos (claro e escuro), em estilo-plasma/.

O Plasma monta o fundo de cada painel com peças de um SVG, escolhidas pelo nome.
O prefixo do nome diz a posição do painel na tela:
- "south": painel de baixo. No bmos é a dock, em vidro com cantos redondos;
- sem prefixo: os outros painéis. No bmos é a barra superior, sem desenho,
  porque cada widget desenha a própria cápsula.

O fundo dos popups (Central de Controle, avisos, busca) segue a mesma ideia,
em dialogs/background.svg: vidro com cantos redondos.

As peças não usam traço (stroke): o Plasma mede cada peça pelo contorno, e o
traço aumenta essa medida em meio pixel, o que faz as peças se sobreporem.

Uso: python3 ferramentas/gerar-estilo.py
"""

import json
import os

AQUI = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
SAIDA = os.path.join(AQUI, "estilo-plasma")

RAIO = 22        # canto da dock

# Medidas da dock, seguindo as proporções do print 02. A altura e o espaçamento
# valem para paineis/montar.js também.
#
# O Plasma só desenha o ícone em tamanhos fixos (48, 64...). Para sair em 64, a
# caixa do ícone precisa ter 64 px livres na altura e na largura:
#   altura da caixa  = altura da dock - recuo de cima - recuo de baixo
#   largura da célula = altura da dock + (recuo esquerdo + direito) x espaçamento
#   largura da caixa  = largura da célula - recuo esquerdo - recuo direito
# Com o espaçamento negativo no widget, os recuos dos lados estreitam a célula, e
# os ícones ficam próximos sem perder a folga em cima e embaixo.
#
# A dock é simétrica: 9 px de folga em volta dos ícones nos quatro lados e 10 px
# entre eles. O desenho do ícone de 64 px já tem 4 px de borda vazia de cada lado,
# e por isso os recuos abaixo são menores que a folga que aparece na tela.
ALTURA_DOCK = 74          # altura do vidro: 64 do ícone + 5 em cima + 5 embaixo
ESPACAMENTO_DOCK = -4     # opção iconSpacing do widget de apps da dock
# Nas pontas, o Plasma deixa no mínimo 10 px entre o vidro e o primeiro ícone, e
# 14 px depois do último (ele soma um espaço seu a mais no fim). Para a folga ser
# de 9 px dos dois lados, o vidro é desenhado mais curto que o painel: 1 px na
# esquerda e 5 px na direita.
RECUO_PONTAS_DOCK = 1       # menor recuo que o Plasma aceita nas pontas do painel
SOBRA_PONTAS_DOCK = (1, 5)  # faixa vazia por fora do vidro: esquerda e direita
# Recuo do ícone dentro da célula de cada app.
RECUO_ICONE = {"top": 5, "bottom": 5, "left": 1, "right": 1}
LARGURA_CELULA = ALTURA_DOCK + (RECUO_ICONE["left"] + RECUO_ICONE["right"]) * ESPACAMENTO_DOCK
RAIO_POPUP = 24  # canto dos popups
RECUO_POPUP = 14 # distância entre a borda do popup e o conteúdo

VARIANTES = {
    "bmos-claro": {
        "nome": "bmos Claro",
        "vidro": ("#ffffff", 0.49), "borda": ("#ffffff", 0.82),
        "popup": ("#f4f2fb", 0.62), "popup_sem_desfoque": ("#f4f2fb", 0.95), "borda_popup": ("#ffffff", 0.95),
        "ponto": ("#464064", 0.75), "realce": ("#ffffff", 0.40),
    },
    "bmos-escuro": {
        "nome": "bmos Escuro",
        "vidro": ("#1e1c36", 0.50), "borda": ("#ffffff", 0.16),
        "popup": ("#1e1c36", 0.66), "popup_sem_desfoque": ("#1e1c36", 0.96), "borda_popup": ("#ffffff", 0.16),
        "ponto": ("#ffffff", 0.80), "realce": ("#ffffff", 0.12),
    },
}


def cor(par):
    return f'fill="{par[0]}" fill-opacity="{par[1]}"'


def vazio(ident, x, y, largura, altura):
    return f'<rect id="{ident}" x="{x}" y="{y}" width="{largura}" height="{altura}" fill="#000000" fill-opacity="0"/>'


def margens():
    # Recuo interno dos painéis: o Plasma soma 4 px a este valor.
    pecas = [vazio("thick-center", 150, 20, 8, 8)]
    for i, borda in enumerate(("top", "bottom", "left", "right")):
        pecas.append(vazio(f"thick-hint-{borda}-margin", 150 + i * 4, 40, 1, 1))
    # As bordas são esticadas, e não repetidas lado a lado: repetidas, as emendas aparecem no vidro.
    pecas.append(vazio("hint-stretch-borders", 150, 60, 4, 4))
    pecas.append(vazio("south-hint-stretch-borders", 160, 60, 4, 4))
    # Sem isto, o recuo das pontas da dock seria a largura do canto redondo (22 px),
    # e os ícones ficariam longe das pontas.
    pecas.append(vazio("south-hint-left-margin", 170, 40, RECUO_PONTAS_DOCK, RECUO_PONTAS_DOCK))
    pecas.append(vazio("south-hint-right-margin", 176, 40, RECUO_PONTAS_DOCK, RECUO_PONTAS_DOCK))
    return pecas


def vidro(prefixo, x0, y0, r, meio, fundo, borda, sobra_esq=0, sobra_dir=0):
    """Nove peças de um retângulo de vidro com cantos redondos, numa grade 3x3.
    O prefixo entra na frente do nome de cada peça ("south-" para o painel de baixo).
    As sobras são faixas vazias por fora das pontas esquerda e direita: o vidro
    aparece mais curto que o painel, e a folga até o conteúdo diminui."""
    pecas = []

    def grupo(ident, x, y, largura, altura, desenho):
        return f'<g id="{prefixo}{ident}">' + vazio(f"{prefixo}{ident}-area", x, y, largura, altura) + desenho + "</g>"

    def canto(ident, x, y, largura, cx, cy, a0, a1):
        # Quarto de círculo com centro em (cx, cy), do ponto a0 ao ponto a1,
        # e por cima um anel de 1 px, que faz a borda clara.
        cheio = f'<path d="M {cx} {cy} L {a0[0]} {a0[1]} A {r} {r} 0 0 1 {a1[0]} {a1[1]} Z" {cor(fundo)}/>'
        rr = r - 1
        def dentro(p):
            return (cx + (p[0] - cx) * rr / r, cy + (p[1] - cy) * rr / r)
        b0, b1 = dentro(a0), dentro(a1)
        anel = (f'<path d="M {a0[0]} {a0[1]} A {r} {r} 0 0 1 {a1[0]} {a1[1]} L {b1[0]} {b1[1]} '
                f'A {rr} {rr} 0 0 0 {b0[0]} {b0[1]} Z" {cor(borda)}/>')
        return grupo(ident, x, y, largura, r, cheio + anel)

    # ve é onde o vidro começa. As peças da esquerda começam antes, em x0.
    ve = x0 + sobra_esq
    xm, xd = ve + r, ve + r + meio
    larg_esq, larg_dir = r + sobra_esq, r + sobra_dir
    yt, ym, yb = y0, y0 + r, y0 + r + meio
    pecas.append(canto("topleft", x0, yt, larg_esq, ve + r, yt + r, (ve, yt + r), (ve + r, yt)))
    pecas.append(canto("topright", xd, yt, larg_dir, xd, yt + r, (xd, yt), (xd + r, yt + r)))
    pecas.append(canto("bottomright", xd, yb, larg_dir, xd, yb, (xd + r, yb), (xd, yb + r)))
    pecas.append(canto("bottomleft", x0, yb, larg_esq, ve + r, yb, (ve + r, yb + r), (ve, yb)))

    def lado(ident, x, y, largura, altura, vx, vl, va, bx, by, bl, ba):
        # (x, y, largura, altura) é a peça; o vidro ocupa vl x va a partir de vx.
        cheio = f'<rect x="{vx}" y="{y}" width="{vl}" height="{va}" {cor(fundo)}/>'
        linha = f'<rect x="{bx}" y="{by}" width="{bl}" height="{ba}" {cor(borda)}/>'
        return grupo(ident, x, y, largura, altura, cheio + linha)

    pecas.append(lado("top", xm, yt, meio, r, xm, meio, r, xm, yt, meio, 1))
    pecas.append(lado("bottom", xm, yb, meio, r, xm, meio, r, xm, yb + r - 1, meio, 1))
    pecas.append(lado("left", x0, ym, larg_esq, meio, ve, r, meio, ve, ym, 1, meio))
    pecas.append(lado("right", xd, ym, larg_dir, meio, xd, r, meio, xd + r - 1, ym, 1, meio))
    pecas.append(f'<rect id="{prefixo}center" x="{xm}" y="{ym}" width="{meio}" height="{meio}" {cor(fundo)}/>')
    return pecas


def painel(v):
    """Barra superior sem desenho, e dock em vidro."""
    pecas = [vazio("center", 0, 0, 16, 16)]
    pecas += vidro("south-", 40, 0, RAIO, 24, v["vidro"], v["borda"], *SOBRA_PONTAS_DOCK)
    return svg(200, 80, pecas + margens())


def popup(v, fundo):
    """Fundo dos popups do Plasma: vidro com cantos redondos."""
    pecas = vidro("", 0, 0, RAIO_POPUP, 24, fundo, v["borda_popup"])
    # O conteúdo fica a RECUO_POPUP da borda, e não à distância do canto redondo.
    for i, borda in enumerate(("top", "bottom", "left", "right")):
        pecas.append(vazio(f"hint-{borda}-margin", 100 + i * 20, 0, RECUO_POPUP, RECUO_POPUP))
    pecas.append(vazio("hint-stretch-borders", 100, 30, 4, 4))
    return svg(200, 80, pecas)


def tarefas(v):
    """Fundo de cada ícone da dock: nada para app fechado, ponto embaixo para app aberto.
    Cada peça já tem o tamanho da célula, e os recuos dizem onde o ícone fica dentro dela."""
    largura, altura, pecas = LARGURA_CELULA, ALTURA_DOCK, []
    passo = largura + 16
    estados = {
        "normal": (True, False, v["ponto"]),
        "focus": (True, False, v["ponto"]),
        "minimized": (True, False, v["ponto"]),
        "attention": (True, False, ("#f19a3e", 1)),
        "hover": (True, True, v["ponto"]),
        "launcher-hover": (False, True, v["ponto"]),
    }
    for i, (nome, (ponto, realce, cor_ponto)) in enumerate(estados.items()):
        x = i * passo
        desenho = vazio(f"{nome}-area", x, 0, largura, altura)
        if realce:
            # Realce em volta do ícone, que fica dentro dos recuos.
            ry = RECUO_ICONE["top"] + 1
            rh = altura - RECUO_ICONE["top"] - RECUO_ICONE["bottom"] - 2
            desenho += f'<rect x="{x + 2}" y="{ry}" width="{largura - 4}" height="{rh}" rx="15" {cor(v["realce"])}/>'
        if ponto:
            # O ponto fica no meio da folga de baixo.
            desenho += f'<circle cx="{x + largura / 2}" cy="{altura - 4.5}" r="2" {cor(cor_ponto)}/>'
        pecas.append(f'<g id="{nome}-center">{desenho}</g>')
        for j, (borda, recuo) in enumerate(RECUO_ICONE.items()):
            pecas.append(vazio(f"{nome}-hint-{borda}-margin", x + j * 10, altura + 6, recuo, recuo))
    return svg(len(estados) * passo, altura + 16, pecas)


def abas(v):
    """Marca da aba ativa nos widgets do Plasma. O Plasma usa a mesma peça para marcar,
    na barra, o widget que está com o painel aberto. Na barra de cima essa marca não
    aparece (a cápsula já mostra onde o painel nasce); nas outras posições é uma linha fina."""
    destaque = ("#5f6ce5", 1)
    pecas = [vazio("north-active-tab-center", 0, 0, 16, 16)]
    # (prefixo, borda onde a linha fica)
    for i, (prefixo, borda) in enumerate((("south-", "top"), ("west-", "right"), ("east-", "left"), ("", "bottom"))):
        x = 30 + i * 30
        pecas.append(vazio(f"{prefixo}active-tab-center", x + 4, 4, 8, 8))
        if borda in ("top", "bottom"):
            y = 2 if borda == "top" else 12
            pecas.append(f'<rect id="{prefixo}active-tab-{borda}" x="{x + 4}" y="{y}" width="8" height="2" {cor(destaque)}/>')
        else:
            xl = x + 2 if borda == "left" else x + 12
            pecas.append(f'<rect id="{prefixo}active-tab-{borda}" x="{xl}" y="4" width="2" height="8" {cor(destaque)}/>')
    return svg(160, 20, pecas)


def svg(largura, altura, pecas):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{largura}" height="{altura}" '
            f'viewBox="0 0 {largura} {altura}">\n' + "\n".join(pecas) + "\n</svg>\n")


def gravar(caminho, texto):
    os.makedirs(os.path.dirname(caminho), exist_ok=True)
    with open(caminho, "w", encoding="utf-8") as arquivo:
        arquivo.write(texto)


for ident, v in VARIANTES.items():
    pasta = os.path.join(SAIDA, ident)
    gravar(os.path.join(pasta, "metadata.json"), json.dumps({
        "KPlugin": {
            "Authors": [{"Name": "bmos"}],
            "Description": "Barra transparente, dock e popups de vidro do bmos",
            "Id": ident,
            "License": "GPL-3.0-or-later",
            "Name": v["nome"],
            "Version": "0.1",
        },
        "X-Plasma-API": "5.0",
    }, indent=4, ensure_ascii=False) + "\n")
    # O Plasma procura o painel também nestas pastas, conforme o modo de opacidade
    # e o desfoque do compositor. Em todas, o desenho é o mesmo.
    for sub in ("", "translucent", "opaque", "solid"):
        gravar(os.path.join(pasta, sub, "widgets", "panel-background.svg"), painel(v))
    gravar(os.path.join(pasta, "widgets", "tasks.svg"), tarefas(v))
    gravar(os.path.join(pasta, "widgets", "tabbar.svg"), abas(v))
    # Com o desfoque do compositor, o popup é de vidro. Sem ele, quase opaco, para o texto continuar legível.
    gravar(os.path.join(pasta, "translucent", "dialogs", "background.svg"), popup(v, v["popup"]))
    gravar(os.path.join(pasta, "dialogs", "background.svg"), popup(v, v["popup_sem_desfoque"]))
    gravar(os.path.join(pasta, "opaque", "dialogs", "background.svg"), popup(v, v["popup_sem_desfoque"]))

print("Estilo gerado em", SAIDA)
