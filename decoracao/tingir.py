#!/usr/bin/env python3
"""Dá à decoração das janelas (barra de título e botões) a tonalidade do bmos.

A decoração MacTahoe tem a barra de título cinza no modo escuro e branca no
claro. As janelas do bmos são azul-violeta, então a barra destoava do resto.
Este roteiro pinta a barra com a cor de cabeçalho do esquema de cores do bmos
(cores/Bmos*.colors), o título com a cor de texto dele, e dá aos cinzas que
sobram (bordas e botões da janela sem foco) o tom da paleta, com a mesma
tabela dos menus (kvantum/montar.py).

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
            if nome.endswith(".svg"):
                novo = recolorir(novo, MODOS[modo]["cinzas"])
                for provisorio, cor in finais.items():
                    novo = novo.replace(provisorio, cor)
            elif nome.endswith("rc"):
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
