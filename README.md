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

## O que fica fora do tema

Um tema instalado na pasta pessoal não alcança algumas partes do sistema: a tela de boot, a tela de login, o desenho da tela de bloqueio e o formato dos menus dos outros apps.

## Componentes de terceiros

O instalador baixa estes componentes dos autores, em versão fixa e conferida. Eles não são redistribuídos aqui.

| Componente | Autor | Licença |
|------------|-------|---------|
| Fonte Inter | Rasmus Andersson | SIL OFL 1.1 |
| Ícones MacTahoe | vinceliuice | GPL-3.0 |
| Decoração de janela MacTahoe para KDE | vinceliuice | LGPL-3.0 |
| Tema GTK MacTahoe | vinceliuice | MIT |
| PySide6 (Qt for Python) | The Qt Company | LGPL-3.0 |

Os ícones de traço das telas são do [Tabler Icons](https://tabler.io/icons), licença MIT, e vêm junto com o tema.

## Licença

GPL-3.0 ou posterior. Veja [LICENSE](LICENSE).
