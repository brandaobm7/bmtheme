#!/usr/bin/env python3
"""Arquivos do bmos: abre a janela de pastas no estilo do Finder.

O comando bmos-arquivos chama este arquivo com o Python do ambiente do tema.

Uso:
  bmos-arquivos            abre a pasta pessoal
  bmos-arquivos PASTA      abre a pasta dada (caminho ou endereço file://)
"""

import os
import sys

AQUI = os.path.dirname(os.path.realpath(__file__))
sys.path[:0] = [AQUI, os.path.join(AQUI, "..", "app-comum")]

from comum import abrir_janela  # noqa: E402  (precisa do caminho acima)
from arquivos import Arquivos   # noqa: E402


def principal():
    livres = [a for a in sys.argv[1:] if not a.startswith("-")]
    return abrir_janela("org.bmos.arquivos", "Arquivos", "system-file-manager",
                        os.path.join(AQUI, "Arquivos.qml"),
                        lambda sistema: {"arquivos": Arquivos(), "pastaInicial": livres[0] if livres else ""})


if __name__ == "__main__":
    sys.exit(principal())
