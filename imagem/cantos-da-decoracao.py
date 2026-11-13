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
    desenha em volta desses dois cantos, continua a sombra no cantinho que fica
    fora do arco e faz a linha acompanhar a curva.
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

// bmos: a imagem da sombra nos dois cantos de baixo. O tema desenha, junto com a
// sombra e do lado de fora da janela, uma linha fina de contorno, que faria um
// canto quadrado em volta do arco. Aqui esse trecho quadrado sai, o cantinho que
// fica fora do arco ganha a continuação da sombra, e a linha passa a acompanhar a
// curva. Esse cantinho fica dentro do retângulo da janela: o KWin só o desenha
// porque o miolo informado para a sombra é menor (bmosMioloDaSombra).
static void bmosCantosDaSombra(QImage &imagem, const QRectF &quadro, qreal raio)
{
    if (raio <= 0) {
        return;
    }
    const int esquerda = qRound(quadro.left());
    const int direita = qRound(quadro.right());
    const int baixo = qRound(quadro.bottom());
    const int r = qRound(raio);
    const int faixa = 2; // a linha tem 1 px; a troca cobre 2
    if (!imagem.valid(esquerda - faixa - 1, baixo + faixa) || !imagem.valid(direita + faixa, baixo - r - 3)) {
        return;
    }
    // A cor da linha de contorno, lida logo acima do trecho que vai mudar.
    const QColor linhaDaEsquerda = imagem.pixelColor(esquerda - 1, baixo - r - 3);
    const QColor linhaDaDireita = imagem.pixelColor(direita, baixo - r - 3);

    auto copiar = [&imagem](int x, int y, int deX, int deY) {
        if (imagem.valid(x, y) && imagem.valid(deX, deY)) {
            imagem.setPixel(x, y, imagem.pixel(deX, deY));
        }
    };
    // 1. Sai o trecho quadrado da linha: cada ponto recebe a cor da sombra logo ao lado.
    for (int i = 0; i < r + faixa; ++i) {
        for (int f = 1; f <= faixa; ++f) {
            copiar(esquerda - f, baixo - r + i, esquerda - faixa - 1, baixo - r + i);
            copiar(direita - 1 + f, baixo - r + i, direita + faixa, baixo - r + i);
            copiar(esquerda - faixa + i, baixo - 1 + f, esquerda - faixa + i, baixo + faixa);
            copiar(direita - 1 + faixa - i, baixo - 1 + f, direita - 1 + faixa - i, baixo + faixa);
        }
    }
    // 2. O cantinho fora do arco continua a sombra: cada ponto pega a cor da borda mais próxima.
    for (int y = baixo - r; y < baixo; ++y) {
        for (int i = 0; i < r; ++i) {
            // i é a distância até a borda lateral; vale para os dois lados.
            const qreal dx = r - (i + 0.5);
            const qreal dy = (y + 0.5) - (baixo - r);
            if (std::hypot(dx, dy) <= r - 1.5) {
                continue; // debaixo da janela
            }
            const bool pelaLateral = i <= (baixo - 1 - y);
            copiar(esquerda + i, y, pelaLateral ? esquerda - 1 : esquerda + i, pelaLateral ? y : baixo);
            copiar(direita - 1 - i, y, pelaLateral ? direita : direita - 1 - i, pelaLateral ? y : baixo);
        }
    }
    // 3. A linha de contorno em curva, 1 px por fora do arco da janela.
    QPainter pintor(&imagem);
    pintor.setRenderHint(QPainter::Antialiasing);
    pintor.setBrush(Qt::NoBrush);
    const qreal diametro = 2 * r + 1;
    QPainterPath arcoDaEsquerda;
    const QRectF caixaDaEsquerda(esquerda - 0.5, baixo - 2 * r - 0.5, diametro, diametro);
    arcoDaEsquerda.arcMoveTo(caixaDaEsquerda, 180);
    arcoDaEsquerda.arcTo(caixaDaEsquerda, 180, 90);
    pintor.setPen(QPen(linhaDaEsquerda, 1, Qt::SolidLine, Qt::FlatCap));
    pintor.drawPath(arcoDaEsquerda);
    QPainterPath arcoDaDireita;
    const QRectF caixaDaDireita(direita - 2 * r - 0.5, baixo - 2 * r - 0.5, diametro, diametro);
    arcoDaDireita.arcMoveTo(caixaDaDireita, 270);
    arcoDaDireita.arcTo(caixaDaDireita, 270, 90);
    pintor.setPen(QPen(linhaDaDireita, 1, Qt::SolidLine, Qt::FlatCap));
    pintor.drawPath(arcoDaDireita);
}

// bmos: o miolo que a sombra não cobre. Sem os cantos arredondados é a janela
// inteira. Com eles, encolhe o tamanho do raio dos lados e embaixo, para as peças
// da sombra alcançarem o cantinho que fica fora do arco.
static QRectF bmosMioloDaSombra(const QRectF &quadro, qreal raio)
{
    if (raio <= 0 || quadro.width() <= 4 * raio || quadro.height() <= 4 * raio) {
        return quadro;
    }
    return quadro.adjusted(raio, 0, -raio, -raio);
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
        (INCLUSAO, INCLUSAO + "#include <QPainterPath>\n#include <cmath>\n\n" + RECORTE),
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
         "        const QRectF bmosQuadro(m_padding->left(), m_padding->top(),\n"
         "                                imageSize.width() - m_padding->left() - m_padding->right(),\n"
         "                                imageSize.height() - m_padding->top() - m_padding->bottom());\n"
         "        bmosCantosDaSombra(img, bmosQuadro, m_raioDosCantos);\n"
         "        if (!updateShadow) {\n            updateShadow = (oldShadow->shadow() != img);\n"),
        ("            s->setInnerShadowRect(QRect(m_padding->left(),\n"
         "                                        m_padding->top(),\n"
         "                                        imageSize.width() - m_padding->left() - m_padding->right(),\n"
         "                                        imageSize.height() - m_padding->top() - m_padding->bottom()));\n",
         "            s->setInnerShadowRect(bmosMioloDaSombra(bmosQuadro, m_raioDosCantos).toRect());\n"),
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
        (INCLUSAO, INCLUSAO + "#include <QPainterPath>\n#include <cmath>\n\n" + RECORTE),
        # O KWin recorta o conteúdo da janela neste raio. Maximizada, não recorta.
        ("        setBorders(m_theme->maximizedBorders(buttonSizeFactor()));\n",
         "        setBorders(m_theme->maximizedBorders(buttonSizeFactor()));\n"
         "        setBorderRadius(KDecoration3::BorderRadius());\n"),
        ("        setBorders(m_theme->borders(settings()->borderSize(), buttonSizeFactor()));\n",
         "        setBorders(m_theme->borders(settings()->borderSize(), buttonSizeFactor()));\n"
         "        setBorderRadius(KDecoration3::BorderRadius(m_theme->bmosCornerRadius()));\n"),
        ("    painter.drawRect(innerRect);\n    painter.end();\n",
         "    painter.drawRect(innerRect);\n    painter.end();\n"
         "    bmosCantosDaSombra(image, innerRect, m_theme->bmosCornerRadius());\n"),
        ("    shadow->setInnerShadowRect(innerRect);\n",
         "    shadow->setInnerShadowRect(bmosMioloDaSombra(innerRect, m_theme->bmosCornerRadius()));\n"),
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
