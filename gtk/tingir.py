#!/usr/bin/env python3
"""Dá aos temas GTK MacTahoe a tonalidade do bmos.

Os apps em GTK (Discos, Loja de Apps, o Chrome no tema do sistema) usam o tema
MacTahoe, que é cinza neutro com realce azul. O resto do bmos é azul-violeta.
Este roteiro troca, nos arquivos do tema, os cinzas pelos tons da paleta do bmos
e o azul pelo azul-violeta, com a mesma tabela dos menus (kvantum/montar.py).

Uso: tingir.py PASTA_DOS_TEMAS    (a pasta onde estão MacTahoe-Light e MacTahoe-Dark)
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "kvantum"))
from montar import MODOS, recolorir  # noqa: E402  (precisa do caminho acima)

VARIANTES = {"MacTahoe-Light": "bmos-claro", "MacTahoe-Dark": "bmos-escuro"}
# Só as partes que os apps usam. As imagens em PNG ficam como estão.
PASTAS = ("gtk-3.0", "gtk-4.0")


def tingir(pasta_dos_temas):
    for tema, modo in VARIANTES.items():
        pontos = MODOS[modo]["cinzas"]
        for parte in PASTAS:
            raiz = os.path.join(pasta_dos_temas, tema, parte)
            for onde, _, arquivos in os.walk(raiz):
                for nome in arquivos:
                    if not nome.endswith((".css", ".svg")):
                        continue
                    caminho = os.path.join(onde, nome)
                    if os.path.islink(caminho):
                        continue
                    with open(caminho, encoding="utf-8", errors="surrogateescape") as arquivo:
                        texto = arquivo.read()
                    novo = recolorir(texto, pontos)
                    if novo != texto:
                        with open(caminho, "w", encoding="utf-8", errors="surrogateescape") as arquivo:
                            arquivo.write(novo)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    tingir(sys.argv[1])
