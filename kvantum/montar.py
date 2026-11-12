#!/usr/bin/env python3
"""Monta os temas do Kvantum do bmos (bmos-claro e bmos-escuro).

O Kvantum é o motor que desenha os menus, botões, campos e listas dos apps do
KDE. O ponto de partida é o tema MacTahoe (vinceliuice, LGPL-3.0), baixado na
instalação e não redistribuído aqui. Este roteiro troca as cores pelas do bmos
e ajusta as medidas para o menu ficar como o do app Arquivos: cartão opaco de
cantos redondos e realce azul-violeta arredondado.

Uso: montar.py PASTA_DO_MACTAHOE PASTA_DE_SAIDA
"""

import os
import re
import sys

# De cada modo: o tema de origem, os cinzas de referência (nível de cinza -> cor do
# bmos) e as cores gerais do Kvantum. Os cinzas entre dois pontos são interpolados.
MODOS = {
    "bmos-claro": {
        "origem": "MacTahoe",
        "cinzas": [(0x00, "#000000"), (0x33, "#1f1d2b"), (0x66, "#6b6880"), (0xa0, "#9b98b0"), (0xc8, "#cfcbe2"),
                   (0xdd, "#e2dff0"), (0xf5, "#f6f5fb"), (0xff, "#ffffff")],
        "cores": {
            "window.color": "#f6f5fb", "inactive.window.color": "#f6f5fb",
            "base.color": "#ffffff", "inactive.base.color": "#ffffff", "alt.base.color": "#f6f5fb",
            "inactive.alt.base.color": "#f6f5fb", "button.color": "#ffffff", "light.color": "#ffffff",
            "mid.light.color": "#eeecf7", "dark.color": "#b9b5cf", "mid.color": "#dcd9ea",
            "highlight.color": "#5f6ce5", "inactive.highlight.color": "#5f6ce5",
            "text.color": "#1f1d2b", "inactive.text.color": "#1f1d2b", "window.text.color": "#1f1d2b",
            "inactive.window.text.color": "#1f1d2b", "button.text.color": "#1f1d2b",
            "disabled.text.color": "#1f1d2b70", "tooltip.base.color": "#ffffff", "tooltip.text.color": "#1f1d2b",
            "highlight.text.color": "#ffffff", "inactive.highlight.text.color": "#ffffff",
            "link.color": "#5463df", "link.visited.color": "#7a4fc9", "progress.indicator.text.color": "#ffffff",
        },
        "cartao": "#ffffff",
        # Contorno e sombra do menu, como no Arquivos: uma linha fina na cor do texto
        # e uma sombra bem leve. (cor da linha, opacidade da linha, opacidade da sombra)
        "contorno": ("#1f1d2b", "0.12", "0.13"),
    },
    "bmos-escuro": {
        "origem": "MacTahoeDark",
        "cinzas": [(0x00, "#000000"), (0x24, "#1e1c36"), (0x33, "#2c294a"), (0x4f, "#45416e"), (0x70, "#68648f"),
                   (0x9d, "#a8a4c4"), (0xdf, "#f2f0fa"), (0xff, "#ffffff")],
        "cores": {
            "window.color": "#1e1c36", "inactive.window.color": "#1e1c36",
            "base.color": "#18162c", "inactive.base.color": "#18162c", "alt.base.color": "#22203c",
            "inactive.alt.base.color": "#22203c", "button.color": "#2c294a", "light.color": "#45416e",
            "mid.light.color": "#35325a", "dark.color": "#121124", "mid.color": "#262443",
            "highlight.color": "#6b77ec", "inactive.highlight.color": "#6b77ec",
            "text.color": "#f2f0fa", "inactive.text.color": "#f2f0fa", "window.text.color": "#f2f0fa",
            "inactive.window.text.color": "#f2f0fa", "button.text.color": "#f2f0fa",
            "disabled.text.color": "#f2f0fa70", "tooltip.base.color": "#2c294a", "tooltip.text.color": "#f2f0fa",
            "highlight.text.color": "#ffffff", "inactive.highlight.text.color": "#ffffff",
            "link.color": "#8f9bff", "link.visited.color": "#b79bff", "progress.indicator.text.color": "#ffffff",
        },
        "cartao": "#2f2c4b",
        "contorno": ("#f2f0fa", "0.16", "0.2"),
    },
}

# Azuis do MacTahoe -> azul-violeta do bmos.
AZUIS = {
    "#0860f2": "#5463df", "#195edc": "#5463df", "#195dda": "#5463df",
    "#315bef": "#5f6ce5", "#3484e2": "#5f6ce5", "#3776e8": "#6b77ec",
    "#5294e2": "#7f8ff8",
}

# Medidas e comportamento, iguais nos dois modos. "seção": {chave: valor}.
AJUSTES = {
    "%General": {
        # Janelas e menus opacos: o cartão do menu do bmos é sólido.
        "translucent_windows": "false", "blurring": "false", "popup_blurring": "false",
        "reduce_menu_opacity": "0", "reduce_window_opacity": "0",
        # Dos 14 px da moldura do menu, 6 são sombra e 8 ficam visíveis: é o raio do canto.
        "menu_shadow_depth": "6",
        "submenu_overlap": "0", "submenu_delay": "140",
    },
    "Menu": {"frame.top": "14", "frame.bottom": "14", "frame.left": "14", "frame.right": "14"},
    "MenuItem": {
        # O realce tem 30 px de altura e cantos de 8 px, como no Arquivos.
        "frame.top": "4", "frame.bottom": "4", "frame.left": "4", "frame.right": "4",
        "frame.expansion": "16",
        "text.margin.top": "2", "text.margin.bottom": "2", "text.margin.left": "8", "text.margin.right": "8",
        "min_height": "30",
    },
}


def para_rgb(cor):
    return tuple(int(cor[i:i + 2], 16) for i in (1, 3, 5))


def cinza_para_bmos(nivel, pontos):
    """A cor do bmos para um nível de cinza, interpolada entre os pontos de referência."""
    for (a, cor_a), (b, cor_b) in zip(pontos, pontos[1:]):
        if a <= nivel <= b:
            t = (nivel - a) / (b - a) if b > a else 0
            return "#%02x%02x%02x" % tuple(round(x + (y - x) * t) for x, y in zip(para_rgb(cor_a), para_rgb(cor_b)))
    return None


def recolorir(texto, pontos):
    """Troca os azuis pelos do bmos e dá aos cinzas o tom violeta da paleta."""
    def trocar(achado):
        cor = achado.group(0).lower()
        base, resto = cor[:7], cor[7:]          # o resto é a transparência, quando há
        if base in AZUIS:
            return AZUIS[base] + resto
        r, g, b = para_rgb(base)
        if max(r, g, b) - min(r, g, b) <= 6 and base not in ("#000000", "#ffffff"):
            return (cinza_para_bmos(round((r + g + b) / 3), pontos) or base) + resto
        return achado.group(0)
    return re.sub(r"#[0-9a-fA-F]{6}(?:[0-9a-fA-F]{2})?\b", trocar, texto)


def menu_opaco(svg, cartao):
    """O fundo e a moldura do menu ficam sólidos, na cor do cartão do bmos.

    No tema de origem o menu é um vidro: branco a 60%. Só as peças do menu usam
    esse branco, então basta achar os desenhos com essa combinação.
    """
    def trocar(achado):
        estilo = dict(parte.split(":", 1) for parte in achado.group(2).split(";") if ":" in parte)
        if estilo.get("opacity") != "0.6" or estilo.get("fill", "").lower() != "#ffffff":
            return achado.group(0)
        estilo["opacity"], estilo["fill"] = "1", cartao
        return achado.group(1) + ";".join(f"{chave}:{valor}" for chave, valor in estilo.items()) + achado.group(3)
    return re.sub(r'(<(?:path|rect)\b[^>]*?\bstyle=")([^"]*)(")', trocar, svg, flags=re.S)


def fim_do_grupo(svg, inicio):
    """Onde termina o grupo que começa em `inicio`, contando os grupos de dentro."""
    fundo = 0
    for marca in re.finditer(r"<g\b[^>]*>|</g>", svg[inicio:], re.S):
        if marca.group(0) == "</g>":
            fundo -= 1
        elif not marca.group(0).endswith("/>"):
            fundo += 1
        if fundo == 0:
            return inicio + marca.end()
    return len(svg)


def sombra_do_menu(svg, contorno):
    """Suaviza a sombra e o contorno do menu, que no tema de origem são fortes."""
    cor, linha, sombra = contorno

    def trocar(achado):
        estilo = dict(parte.split(":", 1) for parte in achado.group(2).split(";") if ":" in parte)
        preenchimento = estilo.get("fill", "").lower()
        if preenchimento.startswith("url("):                    # a sombra é um degradê
            estilo["opacity"] = sombra
        elif preenchimento == "#000000" and "opacity" in estilo:  # a linha do contorno
            estilo["fill"], estilo["opacity"] = cor, linha
        elif preenchimento == "#ffffff" and estilo.get("opacity") == "0.1":
            # Um segundo fio, de brilho, por dentro do contorno: junto com ele, engrossa a borda.
            estilo["opacity"] = "0"
        else:
            return achado.group(0)
        return achado.group(1) + ";".join(f"{chave}:{valor}" for chave, valor in estilo.items()) + achado.group(3)

    # As outras peças da moldura são cópias giradas destas duas.
    for ident in ("menu-shadow-top", "menu-shadow-topright"):
        achado = re.search(r'<g\b[^>]*\bid="%s"' % ident, svg, re.S)
        if not achado:
            continue
        ini, fim = achado.start(), fim_do_grupo(svg, achado.start())
        bloco = re.sub(r'(<(?:path|rect|g)\b[^>]*?\bstyle=")([^"]*)(")', trocar, svg[ini:fim], flags=re.S)
        svg = svg[:ini] + bloco + svg[fim:]
    return svg


def ajustar(config, cores):
    """Aplica as cores gerais e os AJUSTES ao arquivo de configuração do tema."""
    trocas = dict(AJUSTES)
    trocas["GeneralColors"] = cores
    linhas, secao, vistas, saida = config.splitlines(), None, set(), []

    def fechar(nome):
        # Chaves da seção que o tema de origem não tinha entram no fim dela.
        for chave, valor in trocas.get(nome, {}).items():
            if (nome, chave) not in vistas:
                saida.append(f"{chave}={valor}")

    for linha in linhas:
        limpa = linha.strip()
        if limpa.startswith("[") and limpa.endswith("]"):
            if secao is not None:
                while saida and not saida[-1].strip():
                    saida.pop()
                fechar(secao)
                saida.append("")
            secao = limpa[1:-1]
            # O tema de origem repete o título de uma seção: fica um só.
            if saida and saida[-1] == "" and len(saida) > 1 and saida[-2] == limpa:
                saida.pop()
                continue
            saida.append(limpa)
            continue
        if "=" in limpa and secao in trocas:
            chave = limpa.split("=", 1)[0].strip()
            if chave in trocas[secao]:
                saida.append(f"{chave}={trocas[secao][chave]}")
                vistas.add((secao, chave))
                continue
        saida.append(linha)
    if secao is not None:
        fechar(secao)
    return "\n".join(saida) + "\n"


def montar(origem, destino):
    for nome, modo in MODOS.items():
        with open(os.path.join(origem, modo["origem"] + ".svg"), encoding="utf-8") as arquivo:
            svg = arquivo.read()
        with open(os.path.join(origem, modo["origem"] + ".kvconfig"), encoding="utf-8") as arquivo:
            config = arquivo.read()
        if nome == "bmos-claro":
            svg = menu_opaco(svg, modo["cartao"])
            # No claro o tema de origem marca o botão padrão com um triângulo no canto,
            # que parece defeito. Sem a peça, o botão padrão fica igual aos outros.
            svg = svg.replace('id="button-default-indicator"', 'id="sem-uso-button-default-indicator"')
        svg = recolorir(svg, modo["cinzas"])
        svg = sombra_do_menu(svg, modo["contorno"])
        config = ajustar(recolorir(config, modo["cinzas"]), modo["cores"])
        config = config.replace("author=Vince Liuice", "author=bmos, a partir do MacTahoe de Vince Liuice", 1)
        pasta = os.path.join(destino, nome)
        os.makedirs(pasta, exist_ok=True)
        with open(os.path.join(pasta, nome + ".svg"), "w", encoding="utf-8") as arquivo:
            arquivo.write(svg)
        with open(os.path.join(pasta, nome + ".kvconfig"), "w", encoding="utf-8") as arquivo:
            arquivo.write(config)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    montar(sys.argv[1], sys.argv[2])
