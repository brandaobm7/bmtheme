# bmtheme

Tema bmos para o KDE Plasma: uma área de trabalho no estilo do Mac, com identidade própria, feita para o [Bazzite](https://bazzite.gg).

**Em desenvolvimento.** Testado no Bazzite com KDE Plasma 6.4.5, em sessão Wayland. Instala tudo na pasta pessoal, sem senha de administrador, e pode ser desfeito a qualquer momento.

## O que vem no tema

- Barra superior transparente, com uma cápsula de vidro em volta de cada item.
- Dock de vidro, centralizada, com ponto embaixo do app aberto.
- Central de Controle: Wi-Fi, Bluetooth, volume, brilho, perfil de energia e atalhos.
- Grade com todos os apps, e busca no Alt+Espaço.
- Arquivos: gerenciador de pastas no estilo do Finder.
- Ajustes: os ajustes do dia a dia. As Configurações do Sistema do Plasma continuam instaladas para o resto.
- Modo claro e modo escuro, papel de parede, cores, ícones, fonte e tela de abertura.
- Nomes que dizem o que o app faz (Fotos, Mídia, Terminal, Editor de Texto) no lugar dos nomes de marca do KDE. A tabela está em [nomes.conf](nomes.conf).

## Instalar

No terminal do Bazzite:

```bash
git clone https://github.com/brandaobm7/bmtheme.git
```

```bash
cd bmtheme && ./instalar.sh
```

Para já instalar no modo escuro, use `./instalar.sh escuro`.

A instalação baixa a fonte, os ícones e o PySide6 (cerca de 85 MB), e leva em torno de um minuto. A barra e a dock do Plasma são trocadas pelas do tema. A configuração que você tinha fica guardada.

## Usar

Trocar de modo:

```bash
bmos-tema escuro
```

```bash
bmos-tema claro
```

Também dá para trocar pela Central de Controle ou pelo Ajustes.

## Atualizar

```bash
cd bmtheme && git pull && ./instalar.sh
```

## Desinstalar

```bash
cd bmtheme && ./desinstalar.sh
```

O visual, os painéis e os atalhos voltam a ser os que você tinha antes de instalar.

## Imagem bmos

**Em teste.** Além do tema avulso, este repositório constrói uma imagem do Bazzite com o tema já dentro, para quem quer o sistema inteiro pronto. A receita fica em [imagem/](imagem/) e o GitHub a reconstrói todo dia sobre o Bazzite mais recente.

O que muda em relação ao Bazzite:

- O tema bmos é aplicado sozinho no primeiro login de cada usuário, sem baixar nada.
- Saem os apps e serviços que não servem a um computador de jogos com área de trabalho simples. A lista está em [imagem/remover.txt](imagem/remover.txt).
- Os menus e controles dos apps do KDE e a tela de boot ganham o desenho do bmos.
- As janelas com barra de título ganham os cantos de baixo arredondados, como os de cima. Para isso a imagem compila de novo o motor da decoração (Aurorae) com uma troca pequena, numa etapa à parte da construção. A tela de login e a tela de bloqueio ficam com o desenho do Plasma, iguais uma à outra, com o papel de parede, as cores e a fonte do bmos. A tela de bloqueio ganha uma correção para conta sem senha, que no Plasma 6.8 não destravava depois de voltar da suspensão.
- No primeiro boot, entram o Google Chrome e o OnlyOffice, e saem o Firefox e os outros de [imagem/flatpaks-sair.txt](imagem/flatpaks-sair.txt). Os dados desses apps na pasta pessoal não são apagados.

Há uma imagem para cada tipo de placa de vídeo. Escolha a da sua e troque um Bazzite já instalado para ela:

| Placa de vídeo | Imagem |
|----------------|--------|
| AMD ou Intel | `bmtheme` |
| NVIDIA GTX das séries 900 e 1000 | `bmtheme-nvidia` |
| NVIDIA RTX ou GTX 1600 | `bmtheme-nvidia-open` |

```bash
sudo rpm-ostree rebase ostree-unverified-registry:ghcr.io/brandaobm7/bmtheme:latest
```

Troque `bmtheme` pelo nome da imagem da sua placa.

Depois, reinicie. Seus arquivos, jogos e apps continuam como estão. O sistema anterior fica guardado: para voltar a ele, escolha a segunda entrada no menu de boot, ou rode:

```bash
sudo rpm-ostree rollback
```

Para voltar de vez ao Bazzite original:

```bash
sudo rpm-ostree rebase ostree-image-signed:docker://ghcr.io/ublue-os/bazzite:stable
```

Use `bazzite-nvidia` ou `bazzite-nvidia-open` no lugar de `bazzite`, conforme a sua placa.

## O que fica fora do tema

Um tema instalado na pasta pessoal não alcança algumas partes do sistema: a tela de boot, a tela de login, o formato dos menus dos outros apps e os cantos de baixo arredondados das janelas.

## Componentes de terceiros

O instalador baixa estes componentes dos autores, em versão fixa e conferida. Eles não são redistribuídos aqui.

| Componente | Autor | Licença |
|------------|-------|---------|
| Fonte Inter | Rasmus Andersson | SIL OFL 1.1 |
| Ícones MacTahoe | vinceliuice | GPL-3.0 |
| Decoração de janela e tema Kvantum MacTahoe para KDE (base dos menus e controles) | vinceliuice | LGPL-3.0 |
| Tema GTK MacTahoe | vinceliuice | MIT |
| PySide6 (Qt for Python) | The Qt Company | LGPL-3.0 |

Os ícones de traço das telas são do [Tabler Icons](https://tabler.io/icons), licença MIT, e vêm junto com o tema.

## Para quem quer mexer no tema

| Pasta | O que tem |
|-------|-----------|
| [ferramentas/](ferramentas/) | Geradores: o estilo dos painéis do Plasma, o fundo da tela de bloqueio e ícones novos |
| [testes/](testes/) | Testes dos apps com cliques simulados, e o teste de sessão que roda dentro da imagem |
| [imagem/](imagem/) | A receita da imagem bmos |

Os testes dos apps rodam com o tema instalado, a partir da pasta do repositório:

```bash
~/.local/share/bmos-tema/venv/bin/python -u testes/teste_cliques.py arquivos
```

Na imagem bmos, o Python fica em `/usr/lib/bmtheme/venv/bin/python`.

## Licença

GPL-3.0 ou posterior. Veja [LICENSE](LICENSE).
