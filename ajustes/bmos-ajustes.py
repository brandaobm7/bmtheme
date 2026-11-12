#!/usr/bin/env python3
"""Ajustes do bmos: abre a janela com os ajustes do dia a dia.

O comando bmos-ajustes chama este arquivo com o Python do ambiente do tema.

Uso:
  bmos-ajustes             abre na primeira página
  bmos-ajustes PÁGINA      abre numa página: wifi, bluetooth, tela, som, aparencia,
                           perfis, atualizacoes, hardware, data ou sobre
"""

import os
import sys

AQUI = os.path.dirname(os.path.realpath(__file__))
sys.path[:0] = [AQUI, os.path.join(AQUI, "..", "app-comum")]

from comum import abrir_janela  # noqa: E402  (precisa do caminho acima)
from ajustes import Ajustes     # noqa: E402


def principal():
    livres = [a for a in sys.argv[1:] if not a.startswith("-")]
    return abrir_janela("org.bmos.ajustes", "Ajustes", "preferences-system",
                        os.path.join(AQUI, "Ajustes.qml"),
                        lambda sistema: {"ajustes": Ajustes(), "paginaInicial": livres[0] if livres else ""})


if __name__ == "__main__":
    sys.exit(principal())
