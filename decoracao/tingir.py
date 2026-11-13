#!/usr/bin/env python3
"""Dá à decoração das janelas (barra de título e botões) a tonalidade do bmos.

A decoração MacTahoe tem a barra de título cinza no modo escuro e branca no
claro. As janelas do bmos são azul-violeta, então a barra destoava do resto.
Este roteiro pinta a barra com a cor de cabeçalho do esquema de cores do bmos
(cores/Bmos*.colors), o título com a cor de texto dele, e dá aos cinzas que
sobram (bordas e botões da janela sem foco) o tom da paleta, com a mesma
tabela dos menus (kvantum/montar.py).

A sombra em volta da janela também muda: a do MacTahoe é preta e forte, e a
das janelas do bmos (Arquivos e Ajustes) é violeta e leve. Ela passa a ter a
mesma cor e a mesma força da do Arquivos, medidas com as duas janelas sobre
um fundo branco.

Uso: tingir.py PASTA_DOS_TEMAS    (a pasta onde estão MacTahoe-Light e MacTahoe-Dark)
"""

import os
import re
import sys

AQUI = os.path.dirname(os.path.realpath(__file__))
sys.path.insert(0, os.path.join(AQUI, "..", "kvantum"))
from montar import MODOS, recolorir  # noqa: E402  (precisa do caminho acima)

# tema: (modo da tabela de cinzas, esquema de cores, cor da barra com foco, cor da barra sem foco)
MARCA = ".tingido-pelo-bmos"
VARIANTES = {
    "MacTahoe-Light": ("bmos-claro", "BmosClaro.colors", "#ffffff", "#f2f2f2"),
    "MacTahoe-Dark": ("bmos-escuro", "BmosEscuro.colors", "#333333", "#242424"),
}


def ler_esquema(nome):
    """As seções e chaves de um esquema de cores do KDE: {"seção": {"chave": "valor"}}."""
    secoes, atual = {}, None
    with open(os.path.join(AQUI, "..", "cores", nome), encoding="utf-8") as arquivo:
        for linha in arquivo:
            linha = linha.strip()
            if linha.startswith("["):
                atual = secoes.setdefault(linha, {})
            elif "=" in linha and atual is not None:
                chave, valor = linha.split("=", 1)
                atual[chave] = valor
    return secoes


def em_hex(rgb):
    return "#%02x%02x%02x" % tuple(int(parte) for parte in rgb.split(","))


def pintar_barra(svg, trocas):
    """Troca a cor das peças opacas da barra. As linhas de brilho, translúcidas, ficam."""
    def trocar(achado):
        estilo = dict(parte.split(":", 1) for parte in achado.group(1).split(";") if ":" in parte)
        cor = estilo.get("fill", "").strip().lower()
        opaca = float(estilo.get("fill-opacity", 1)) * float(estilo.get("opacity", 1)) == 1
        if cor not in trocas or not opaca:
            return achado.group(0)
        return achado.group(0).replace("fill:" + estilo["fill"], "fill:" + trocas[cor])

    return re.sub(r'style="([^"]*)"', trocar, svg)


# Sombra da janela, igual à do Arquivos (arquivos/Arquivos.qml): a cor e, para cada
# lado, a opacidade da peça. Os degradês do MacTahoe continuam dando o formato.
COR_DA_SOMBRA = "#292159"
# Raio dos cantos de cima da barra de título do MacTahoe, em px, medido no desenho.
RAIO_DOS_CANTOS = 24
FORCA_DA_SOMBRA = {
    "bottom": "0.247", "left": "0.224", "right": "0.224", "top": "0.175",
    "bottomleft": "0.235", "bottomright": "0.235", "topleft": "0.2", "topright": "0.2",
}


def suavizar_sombra(svg):
    """Dá à sombra da decoração a cor e a força da sombra das janelas do bmos."""
    # Os degradês da sombra são os únicos do arquivo, e todos pretos.
    svg = re.sub(r"<stop\b[^>]*>", lambda achado: achado.group(0).replace("stop-color:#000000", "stop-color:" + COR_DA_SOMBRA), svg)
    # Cada peça de sombra é um desenho preenchido com um degradê, dentro do grupo do seu lado.
    grupos = [(achado.start(), achado.group(1)) for achado in
              re.finditer(r'<g\b[^>]*\bid="decoration-(?:inactive-)?([a-z]+)"', svg)]

    def trocar(achado):
        estilo = achado.group(1)
        if "fill:url(#" not in estilo:
            return achado.group(0)
        lado = next((nome for inicio, nome in reversed(grupos) if inicio < achado.start()), None)
        forca = FORCA_DA_SOMBRA.get(lado)
        if not forca:
            return achado.group(0)
        if re.search(r"(?<![-\w])opacity:", estilo):
            novo = re.sub(r"(?<![-\w])opacity:[0-9.]+", "opacity:" + forca, estilo)
        else:
            novo = "opacity:" + forca + ";" + estilo
        return 'style="' + novo + '"'

    return re.sub(r'style="([^"]*)"', trocar, svg)


def tingir(pasta_dos_temas):
    for tema, (modo, esquema, com_foco, sem_foco) in VARIANTES.items():
        pasta = os.path.join(pasta_dos_temas, tema)
        # Tingir duas vezes mudaria as cores de novo: a marca evita.
        marca = os.path.join(pasta, MARCA)
        if os.path.exists(marca):
            continue
        cores = ler_esquema(esquema)
        # A barra ganha primeiro um nome provisório no lugar da cor, para a troca
        # dos cinzas, que vem depois, não mexer na cor já escolhida.
        trocas = {com_foco: "@com-foco@", sem_foco: "@sem-foco@"}
        finais = {
            "@com-foco@": em_hex(cores["[Colors:Header]"]["BackgroundNormal"]),
            "@sem-foco@": em_hex(cores["[Colors:Header][Inactive]"]["BackgroundNormal"]),
        }
        for nome in sorted(os.listdir(pasta)):
            caminho = os.path.join(pasta, nome)
            with open(caminho, encoding="utf-8") as arquivo:
                texto = arquivo.read()
            novo = texto
            if nome == "decoration.svg":
                novo = pintar_barra(novo, trocas)
                novo = suavizar_sombra(novo)
            if nome.endswith(".svg"):
                novo = recolorir(novo, MODOS[modo]["cinzas"])
                for provisorio, cor in finais.items():
                    novo = novo.replace(provisorio, cor)
            elif nome.endswith("rc"):
                # O raio dos cantos da janela, igual ao dos cantos de cima do desenho. Só o
                # Aurorae da imagem bmos lê esta chave (imagem/cantos-da-decoracao.py).
                if "BmosCornerRadius" not in novo:
                    novo = novo.replace("[General]\n", "[General]\nBmosCornerRadius=%d\n" % RAIO_DOS_CANTOS, 1)
                novo = re.sub(r"(?m)^ActiveTextColor=.*$", "ActiveTextColor=" + cores["[WM]"]["activeForeground"], novo)
                novo = re.sub(r"(?m)^InactiveTextColor=.*$",
                              "InactiveTextColor=" + cores["[WM]"]["inactiveForeground"], novo)
            if novo != texto:
                with open(caminho, "w", encoding="utf-8") as arquivo:
                    arquivo.write(novo)
        open(marca, "w").close()


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    tingir(sys.argv[1])
