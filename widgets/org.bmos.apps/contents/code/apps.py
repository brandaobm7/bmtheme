#!/usr/bin/env python3
"""Lista os apps instalados para a grade "Todos os apps" do bmos.

Lê os arquivos .desktop das pastas de aplicativos do sistema, do Flatpak e da
pessoa, como o menu do Plasma faz, e mostra o resultado em JSON. Só usa a
biblioteca padrão do Python.

Uso:
  apps.py        lista os apps: nome, ícone, caminho do .desktop e termos de busca
"""

import json
import locale
import os
import shutil
import sys
import unicodedata


def pastas():
    """Pastas de aplicativos, da mais para a menos prioritária."""
    casa = os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share")
    outras = os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share"
    vistas, lista = set(), []
    for base in [casa] + outras.split(":"):
        pasta = os.path.join(base, "applications")
        if base and pasta not in vistas and os.path.isdir(pasta):
            vistas.add(pasta)
            lista.append(pasta)
    return lista


def idiomas():
    """Sufixos de tradução a tentar, do mais específico ao mais geral: pt_BR, pt."""
    codigo = (os.environ.get("LC_ALL") or os.environ.get("LC_MESSAGES") or os.environ.get("LANG") or "").split(".")[0]
    if not codigo or codigo in ("C", "POSIX"):
        return []
    return [codigo, codigo.split("_")[0]] if "_" in codigo else [codigo]


def ler(caminho):
    """Devolve as chaves do grupo [Desktop Entry] de um arquivo .desktop."""
    chaves, dentro = {}, False
    try:
        with open(caminho, encoding="utf-8", errors="replace") as arquivo:
            for linha in arquivo:
                linha = linha.strip()
                if linha.startswith("["):
                    dentro = linha == "[Desktop Entry]"
                elif dentro and "=" in linha and not linha.startswith("#"):
                    chave, valor = linha.split("=", 1)
                    chaves[chave.strip()] = valor.strip()
    except OSError:
        return {}
    return chaves


def traduzido(chaves, nome, sufixos):
    for sufixo in sufixos:
        valor = chaves.get(f"{nome}[{sufixo}]")
        if valor:
            return valor
    return chaves.get(nome, "")


def aparece(chaves):
    """Diz se o app entra no menu do Plasma."""
    if chaves.get("Type") != "Application" or not chaves.get("Name"):
        return False
    if chaves.get("NoDisplay", "").lower() == "true" or chaves.get("Hidden", "").lower() == "true":
        return False
    # Apps que a tabela de nomes do bmos tira da grade (nomes.conf e bmos-nomes).
    if chaves.get("X-Bmos-Esconder", "").lower() == "true":
        return False
    so_em = [a for a in chaves.get("OnlyShowIn", "").split(";") if a]
    if so_em and "KDE" not in so_em:
        return False
    if "KDE" in chaves.get("NotShowIn", "").split(";"):
        return False
    teste = chaves.get("TryExec")
    if teste and not shutil.which(teste):
        return False
    return True


def sem_acento(texto):
    return "".join(c for c in unicodedata.normalize("NFD", texto.lower()) if unicodedata.category(c) != "Mn")


def listar():
    sufixos, vistos, apps = idiomas(), set(), []
    for pasta in pastas():
        for raiz, _, arquivos in os.walk(pasta):
            for nome in arquivos:
                if not nome.endswith(".desktop"):
                    continue
                caminho = os.path.join(raiz, nome)
                # O mesmo app em duas pastas vale só na primeira, que tem prioridade.
                ident = os.path.relpath(caminho, pasta).replace(os.sep, "-")
                if ident in vistos:
                    continue
                vistos.add(ident)
                chaves = ler(caminho)
                if not aparece(chaves):
                    continue
                titulo = traduzido(chaves, "Name", sufixos)
                extras = " ".join([traduzido(chaves, "GenericName", sufixos), traduzido(chaves, "Keywords", sufixos),
                                   chaves.get("Name", ""), chaves.get("X-Bmos-Nome", "")])
                apps.append({
                    "nome": titulo,
                    "icone": chaves.get("Icon", "") or "application-x-executable",
                    "caminho": caminho,
                    "termos": sem_acento(titulo + " " + extras),
                })
    apps.sort(key=lambda app: sem_acento(app["nome"]))
    return apps


if __name__ == "__main__":
    try:
        locale.setlocale(locale.LC_ALL, "")
    except locale.Error:
        pass
    json.dump(listar(), sys.stdout, ensure_ascii=False)
