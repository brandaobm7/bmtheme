#!/usr/bin/env python3
"""Ensina o motor da decoração das janelas (Aurorae) a arredondar os cantos de baixo.

O tema de decoração (MacTahoe) desenha a barra de título com os cantos de cima
redondos, mas os de baixo são do conteúdo do app, que é um retângulo. O KWin
sabe recortar o conteúdo de uma janela quando a decoração informa o raio, e a
decoração padrão do Plasma (Breeze) faz isso. O Aurorae, que desenha os temas
em SVG, não informa.

Este roteiro faz poucas trocas no código-fonte do Aurorae:
  - ele lê o raio no arquivo do tema (chave BmosCornerRadius, que
    decoracao/tingir.py grava) e o informa ao KWin, que recorta o conteúdo do app;
  - ao pintar a moldura, apaga dela o que fica fora do arco nos dois cantos de
    baixo, porque o KWin não recorta a moldura, só o conteúdo;
  - na imagem da sombra, tira o trecho quadrado da linha de contorno que o tema
    desenha em volta desses dois cantos.
Tema sem a chave fica como sempre foi. Janela maximizada não tem canto recortado.

O Aurorae tem dois motores, e o KWin escolhe um ou outro para o mesmo tema: a
primeira versão (pasta v1) enquanto a sessão em que o tema foi aplicado está
aberta, e a segunda (v2) depois que o KWin reinicia. As trocas vão nas duas.

Uso: cantos-da-decoracao.py PASTA_DO_CODIGO_DO_AURORAE
Sai com erro, sem alterar nada, se o código desta versão não tiver os trechos esperados.
"""

import os
import sys

# Apaga da moldura, já pintada, o que fica fora do arco nos dois cantos de baixo.
RECORTE = """// bmos: apaga da moldura o que fica fora do arco nos dois cantos de baixo
// (imagem/cantos-da-decoracao.py).
static void bmosRecortarCantos(QPainter *painter, const QRectF &quadro, qreal raio)
{
    if (raio <= 0) {
        return;
    }
    QPainterPath quadrados;
    quadrados.addRect(QRectF(quadro.left(), quadro.bottom() - raio, raio, raio));
    quadrados.addRect(QRectF(quadro.right() - raio, quadro.bottom() - raio, raio, raio));
    QPainterPath discos;
    discos.addEllipse(QPointF(quadro.left() + raio, quadro.bottom() - raio), raio, raio);
    discos.addEllipse(QPointF(quadro.right() - raio, quadro.bottom() - raio), raio, raio);
    painter->save();
    painter->setRenderHint(QPainter::Antialiasing);
    painter->setCompositionMode(QPainter::CompositionMode_DestinationOut);
    painter->setPen(Qt::NoPen);
    painter->setBrush(Qt::black);
    painter->drawPath(quadrados.subtracted(discos));
    painter->restore();
}

// bmos: o tema desenha uma linha fina de contorno junto com a sombra, do lado de
// fora da janela. Nos dois cantos de baixo ela faria um canto quadrado em volta
// do arco. Aqui cada ponto desse trecho recebe a cor da sombra logo ao lado.
static void bmosLimparContorno(QImage &imagem, const QRectF &quadro, qreal raio)
{
    if (raio <= 0) {
        return;
    }
    const int esquerda = qRound(quadro.left());
    const int direita = qRound(quadro.right());
    const int baixo = qRound(quadro.bottom());
    const int r = qRound(raio);
    const int faixa = 2; // a linha tem 1 px; a troca cobre 2
    auto copiar = [&imagem](int x, int y, int deX, int deY) {
        if (imagem.valid(x, y) && imagem.valid(deX, deY)) {
            imagem.setPixel(x, y, imagem.pixel(deX, deY));
        }
    };
    for (int i = 0; i < r + faixa; ++i) {
        for (int f = 1; f <= faixa; ++f) {
            // os dois trechos verticais
            copiar(esquerda - f, baixo - r + i, esquerda - faixa - 1, baixo - r + i);
            copiar(direita - 1 + f, baixo - r + i, direita + faixa, baixo - r + i);
            // os dois trechos da linha de baixo
            copiar(esquerda - faixa + i, baixo - 1 + f, esquerda - faixa + i, baixo + faixa);
            copiar(direita - 1 + faixa - i, baixo - 1 + f, direita - 1 + faixa - i, baixo + faixa);
        }
    }
}
"""
INCLUSAO = "#include <QPainter>\n"

# arquivo: [(trecho do Aurorae, trecho novo), ...]. Cada trecho tem de aparecer uma vez só.
TROCAS = {
    # Primeira versão do motor.
    "v1/aurorae.h": [
        ("    QString m_themeName;\n",
         "    QString m_themeName;\n"
         "    qreal m_raioDosCantos = 0; // bmos: raio dos cantos da janela, lido do arquivo do tema\n"),
    ],
    "v1/aurorae.cpp": [
        (INCLUSAO, INCLUSAO + "#include <QPainterPath>\n\n" + RECORTE),
        ("        theme->loadTheme(themeName, config);\n",
         "        theme->loadTheme(themeName, config);\n"
         "        // bmos: o tema diz o raio dos cantos da janela.\n"
         "        m_raioDosCantos = config.group(QStringLiteral(\"General\")).readEntry(\"BmosCornerRadius\", 0.0);\n"),
        ("    setBorders(*b);\n\n    updateExtendedBorders();\n",
         "    setBorders(*b);\n"
         "    // bmos: o KWin recorta o conteúdo da janela neste raio. Maximizada, não recorta.\n"
         "    setBorderRadius(KDecoration3::BorderRadius(window()->isMaximized() ? 0.0 : m_raioDosCantos));\n\n"
         "    updateExtendedBorders();\n"),
        ("    painter->drawImage(rect(), image, nativeContentRect);\n",
         "    painter->drawImage(rect(), image, nativeContentRect);\n"
         "    bmosRecortarCantos(painter, QRectF(rect()), window()->isMaximized() ? 0.0 : m_raioDosCantos);\n"),
        ("        if (!updateShadow) {\n            updateShadow = (oldShadow->shadow() != img);\n",
         "        p.end();\n"
         "        bmosLimparContorno(img, QRectF(m_padding->left(), m_padding->top(),\n"
         "                                       imageSize.width() - m_padding->left() - m_padding->right(),\n"
         "                                       imageSize.height() - m_padding->top() - m_padding->bottom()), m_raioDosCantos);\n"
         "        if (!updateShadow) {\n            updateShadow = (oldShadow->shadow() != img);\n"),
    ],
    # Segunda versão do motor.
    "v2/decorationtheme.h": [
        ("    QMarginsF borders(KDecoration3::BorderSize borderSize, qreal buttonSizeFactor) const;\n",
         "    QMarginsF borders(KDecoration3::BorderSize borderSize, qreal buttonSizeFactor) const;\n"
         "    // bmos: raio dos cantos da janela, lido do arquivo do tema.\n"
         "    qreal bmosCornerRadius() const { return m_bmosCornerRadius; }\n"),
        ("    QString m_themeName;\n",
         "    QString m_themeName;\n"
         "    qreal m_bmosCornerRadius = 0;\n"),
    ],
    "v2/decorationtheme.cpp": [
        ("    KConfigGroup general(&config, QStringLiteral(\"General\"));\n",
         "    KConfigGroup general(&config, QStringLiteral(\"General\"));\n"
         "    m_bmosCornerRadius = general.readEntry(\"BmosCornerRadius\", 0.0);\n"),
    ],
    "v2/decoration.cpp": [
        (INCLUSAO, INCLUSAO + "#include <QPainterPath>\n\n" + RECORTE),
        # O KWin recorta o conteúdo da janela neste raio. Maximizada, não recorta.
        ("        setBorders(m_theme->maximizedBorders(buttonSizeFactor()));\n",
         "        setBorders(m_theme->maximizedBorders(buttonSizeFactor()));\n"
         "        setBorderRadius(KDecoration3::BorderRadius());\n"),
        ("        setBorders(m_theme->borders(settings()->borderSize(), buttonSizeFactor()));\n",
         "        setBorders(m_theme->borders(settings()->borderSize(), buttonSizeFactor()));\n"
         "        setBorderRadius(KDecoration3::BorderRadius(m_theme->bmosCornerRadius()));\n"),
        ("    painter.drawRect(innerRect);\n    painter.end();\n",
         "    painter.drawRect(innerRect);\n    painter.end();\n"
         "    bmosLimparContorno(image, innerRect, m_theme->bmosCornerRadius());\n"),
        ("    if (m_rightButtons->geometry().intersects(repaintRegion)) {\n"
         "        m_rightButtons->paint(painter, repaintRegion);\n"
         "    }\n"
         "}\n",
         "    if (m_rightButtons->geometry().intersects(repaintRegion)) {\n"
         "        m_rightButtons->paint(painter, repaintRegion);\n"
         "    }\n"
         "    bmosRecortarCantos(painter, QRectF(QPointF(0, 0), size()), window()->isMaximized() ? 0.0 : m_theme->bmosCornerRadius());\n"
         "}\n"),
    ],
}


def principal():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    novos = {}
    for nome, trocas in TROCAS.items():
        caminho = os.path.join(sys.argv[1], nome)
        try:
            with open(caminho, encoding="utf-8") as arquivo:
                texto = arquivo.read()
        except OSError:
            sys.exit(f"Não achei {caminho}.")
        for do_aurorae, novo in trocas:
            if texto.count(do_aurorae) != 1:
                sys.exit(f"O {nome} desta versão do Aurorae mudou. Trecho não encontrado:\n{do_aurorae}")
            texto = texto.replace(do_aurorae, novo)
        novos[caminho] = texto
    for caminho, texto in novos.items():
        with open(caminho, "w", encoding="utf-8") as arquivo:
            arquivo.write(texto)
    print("Código do Aurorae com o raio dos cantos.")


if __name__ == "__main__":
    principal()
