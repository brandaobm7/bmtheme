#!/usr/bin/env python3
"""Estado e ações da Central de Controle do bmos no KDE Plasma.

Só usa a biblioteca padrão do Python e comandos que já vêm no sistema
(nmcli, bluetoothctl, rfkill, wpctl, busctl, kreadconfig6 e kwriteconfig6).

Uso:
  central.py estado                     mostra o estado em JSON
  central.py wifi ligar|desligar
  central.py bluetooth ligar|desligar
  central.py volume 0-100
  central.py mudo                       liga ou desliga o som
  central.py brilho 1-100
  central.py perfil economico|alto|game
  central.py tema claro|escuro
  central.py luz ligar|desligar         luz noturna
"""

import glob
import json
import os
import re
import shutil
import subprocess
import sys

# Nomes do bmos para os perfis de energia do sistema.
PERFIS = {"power-saver": "economico", "balanced": "alto", "performance": "game"}
PERFIS_DBUS = ("net.hadess.PowerProfiles", "org.freedesktop.UPower.PowerProfiles")
BRILHO = ("org.kde.Solid.PowerManagement", "/org/kde/Solid/PowerManagement/Actions/BrightnessControl",
          "org.kde.Solid.PowerManagement.Actions.BrightnessControl")
LUZ = ("org.kde.KWin", "/org/kde/KWin/NightLight", "org.kde.KWin.NightLight")


def rodar(comando, tempo=6):
    """Roda um comando e devolve (código, saída). Nunca levanta exceção."""
    try:
        r = subprocess.run(comando, capture_output=True, text=True, timeout=tempo)
        return r.returncode, r.stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return 1, ""


def tem(comando):
    return shutil.which(comando) is not None


def campos_nmcli(linha):
    """Separa uma linha do "nmcli -t", que escapa os dois-pontos do texto com barra."""
    return [c.replace("\\:", ":").replace("\\\\", "\\") for c in re.split(r"(?<!\\):", linha)]


def dbus(barramento, destino, caminho, interface, *resto):
    """Chama o busctl e devolve o valor da resposta, sem o tipo na frente."""
    codigo, saida = rodar(["busctl", barramento, *resto[:1], destino, caminho, interface, *resto[1:]])
    if codigo != 0 or not saida:
        return None
    partes = saida.split(" ", 1)
    return partes[1].strip('"') if len(partes) > 1 else ""


# ------------------------------------------------------------------ leitura

def ler_wifi():
    e = {"wifiDisponivel": False, "wifiLigado": False, "wifiRede": ""}
    if not tem("nmcli"):
        return e
    _, aparelhos = rodar(["nmcli", "-t", "-f", "TYPE", "device"])
    e["wifiDisponivel"] = "wifi" in aparelhos.splitlines()
    _, radio = rodar(["nmcli", "-t", "-f", "WIFI", "general"])
    e["wifiLigado"] = e["wifiDisponivel"] and radio == "enabled"
    if e["wifiLigado"]:
        _, redes = rodar(["nmcli", "-t", "-f", "ACTIVE,SSID", "device", "wifi", "list", "--rescan", "no"])
        for linha in redes.splitlines():
            campos = campos_nmcli(linha)
            if len(campos) >= 2 and campos[0] in ("yes", "sim"):
                e["wifiRede"] = campos[1]
                break
    return e


def ler_bluetooth():
    e = {"btDisponivel": False, "btLigado": False}
    if not tem("bluetoothctl"):
        return e
    _, saida = rodar(["bluetoothctl", "show"])
    e["btDisponivel"] = "Powered:" in saida
    e["btLigado"] = "Powered: yes" in saida
    return e


def ler_som():
    e = {"somDisponivel": False, "volume": 0, "mudo": False}
    codigo, saida = rodar(["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"])
    achado = re.search(r"Volume:\s*([0-9.]+)", saida)
    if codigo == 0 and achado:
        e["somDisponivel"] = True
        e["volume"] = min(100, round(float(achado.group(1)) * 100))
        e["mudo"] = "MUTED" in saida
    return e


def ler_brilho():
    e = {"brilhoDisponivel": False, "brilho": 0}
    if not glob.glob("/sys/class/backlight/*"):
        return e
    atual = dbus("--user", *BRILHO, "call", "brightness")
    maximo = dbus("--user", *BRILHO, "call", "brightnessMax")
    if atual and maximo and atual.isdigit() and maximo.isdigit() and int(maximo) > 0:
        e["brilhoDisponivel"] = True
        e["brilho"] = round(int(atual) * 100 / int(maximo))
    return e


def ler_bateria():
    e = {"bateria": -1, "carregando": False}
    for pasta in sorted(glob.glob("/sys/class/power_supply/BAT*")):
        try:
            with open(os.path.join(pasta, "capacity"), encoding="utf-8") as arquivo:
                e["bateria"] = int(arquivo.read().strip())
            with open(os.path.join(pasta, "status"), encoding="utf-8") as arquivo:
                e["carregando"] = arquivo.read().strip() in ("Charging", "Full")
            break
        except (OSError, ValueError):
            continue
    return e


def servico_perfis():
    for nome in PERFIS_DBUS:
        caminho = "/" + nome.replace(".", "/")
        valor = dbus("--system", nome, caminho, nome, "get-property", "ActiveProfile")
        if valor is not None:
            return nome, caminho, valor
    return None, None, None


def ler_perfil():
    servico, caminho, valor = servico_perfis()
    e = {"perfilDisponivel": valor is not None, "perfil": PERFIS.get(valor or "", "alto"), "perfis": []}
    if servico:
        # A lista vem numa estrutura grande; basta saber quais nomes aparecem nela.
        _, lista = rodar(["busctl", "--system", "get-property", servico, caminho, servico, "Profiles"])
        e["perfis"] = [nosso for deles, nosso in PERFIS.items() if f'"{deles}"' in lista]
    return e


def ler_tema():
    caminho = os.path.expanduser("~/.config/bmos/tema")
    try:
        with open(caminho, encoding="utf-8") as arquivo:
            tema = arquivo.read().strip()
    except OSError:
        tema = "claro"
    return {"tema": "escuro" if tema == "escuro" else "claro"}


def ler_luz():
    disponivel = dbus("--user", *LUZ, "get-property", "available")
    ligada = dbus("--user", *LUZ, "get-property", "running")
    return {"luzDisponivel": disponivel == "true", "luzNoturna": ligada == "true"}


def estado():
    e = {}
    for leitura in (ler_wifi, ler_bluetooth, ler_som, ler_brilho, ler_bateria, ler_perfil, ler_tema, ler_luz):
        e.update(leitura())
    return e


# ------------------------------------------------------------------ ações

def numero(texto, minimo, maximo):
    try:
        return max(minimo, min(maximo, int(float(texto))))
    except ValueError:
        sys.exit(2)


def acao(nome, valor):
    if nome == "wifi":
        rodar(["nmcli", "radio", "wifi", "on" if valor == "ligar" else "off"])
    elif nome == "bluetooth":
        if valor == "ligar":
            rodar(["rfkill", "unblock", "bluetooth"])
        rodar(["bluetoothctl", "power", "on" if valor == "ligar" else "off"])
    elif nome == "volume":
        rodar(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "0"])
        rodar(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", f"{numero(valor, 0, 100) / 100:.2f}"])
    elif nome == "mudo":
        rodar(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])
    elif nome == "brilho":
        maximo = dbus("--user", *BRILHO, "call", "brightnessMax")
        if maximo and maximo.isdigit():
            alvo = round(int(maximo) * numero(valor, 1, 100) / 100)
            rodar(["busctl", "--user", "call", *BRILHO, "setBrightnessSilent", "i", str(alvo)])
    elif nome == "perfil":
        servico, caminho, _ = servico_perfis()
        alvo = {v: k for k, v in PERFIS.items()}.get(valor)
        if servico and alvo:
            rodar(["busctl", "--system", "set-property", servico, caminho, servico, "ActiveProfile", "s", alvo])
    elif nome == "tema":
        if valor in ("claro", "escuro"):
            rodar([os.path.expanduser("~/.local/bin/bmos-tema"), valor], tempo=40)
    elif nome == "luz":
        # Quem nunca escolheu um horário nas Configurações do Sistema ganha a luz noturna
        # sempre acesa ao ligar. Quem já escolheu continua com o horário que definiu.
        # O "--notify" avisa o KWin na hora; sem ele a mudança só vale na próxima sessão.
        _, modo = rodar(["kreadconfig6", "--file", "kwinrc", "--group", "NightColor", "--key", "Mode"])
        if valor == "ligar" and not modo:
            rodar(["kwriteconfig6", "--notify", "--file", "kwinrc", "--group", "NightColor", "--key", "Mode", "Constant"])
        rodar(["kwriteconfig6", "--notify", "--file", "kwinrc", "--group", "NightColor", "--key", "Active",
               "true" if valor == "ligar" else "false"])
    else:
        sys.exit(2)


def principal():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    if sys.argv[1] != "estado":
        acao(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else "")
    print(json.dumps(estado(), ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(principal())
