#!/usr/bin/env python3
"""Gera a arte decorativa da landing (mata, copa e favicon), sem dependências.

Uso, da raiz do repositório: python3 documentacao/landing/tools/gen_arte.py
(grava em docs/assets/, de forma determinística)
Usa só cores da paleta do jogo e o primeiro quadro do Paquicéfalo do jogo (CC BY 4.0).
"""
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
from png_util import gravar, ler

AQUI = os.path.dirname(os.path.abspath(__file__))
SAIDA = os.path.join(AQUI, "..", "..", "..", "docs", "assets")
JOGO = os.path.join(AQUI, "..", "..", "..", "game", "assets")
VAZIO = (0, 0, 0, 0)
def cor(h): return (int(h[1:3], 16), int(h[3:5], 16), int(h[5:7], 16), 255)
TINTA, ESCURO, MEDIO, CLARO = cor("#141b1b"), cor("#345a52"), cor("#56864c"), cor("#74a334")
FUNDO, FUNDO_MARCA = cor("#1c332e"), cor("#243f39")


def tela(l, a, c=VAZIO): return [[c] * l for _ in range(a)]


def selva():
    """Tile 64x64 de mata fechada: fundo escuro com folhinhas espalhadas."""
    t, rnd = tela(64, 64, FUNDO), random.Random(11)
    for i in range(46):
        x, y, c = rnd.randrange(64), rnd.randrange(64), (ESCURO if i % 3 == 0 else FUNDO_MARCA)
        for dx, dy in ((0, 0), (1, -1), (2, -1), (1, 0)):
            t[(y + dy) % 64][(x + dx) % 64] = c
    return t


def folha(t, cx, y0, comp, larg, lean, cor_miolo, cor_luz):
    """Folha em gota apontando para baixo, com contorno, luz na esquerda e nervura."""
    L, pts = len(t[0]), {}
    for y in range(y0, y0 + comp):
        k = (y - y0) / comp
        hw = (larg / 2) * (1 - k) ** 0.7
        c = cx + lean * k * comp
        for x in range(round(c - hw), round(c + hw) + 1):
            pts[(x, y)] = cor_luz if x < round(c) else cor_miolo
        pts[(round(c), y)] = ESCURO if y > y0 + 2 else cor_miolo
    for (x, y), v in pts.items():
        borda = any((x + dx, y + dy) not in pts for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
        if y >= 6 and y < len(t):
            t[y][x % L] = TINTA if borda else v


def copa():
    """Faixa 64x32 de folhas pendendo do alto, para encaixar no topo das seções."""
    t, rnd = tela(64, 32), random.Random(5)
    for y in range(6):
        t[y] = [ESCURO] * 64
    for cx in (8, 24, 40, 56):
        folha(t, cx, 4, rnd.randint(16, 24), 12, rnd.choice((-0.2, 0.2)), ESCURO, MEDIO)
    for cx in (0, 15, 33, 49):
        folha(t, cx + rnd.randint(0, 3), 4, rnd.randint(10, 20), 11, rnd.choice((-0.25, 0.25)), MEDIO, CLARO)
    return t


def main():
    gravar(os.path.join(SAIDA, "selva.png"), selva())
    gravar(os.path.join(SAIDA, "copa.png"), copa())
    _, _, p = ler(os.path.join(SAIDA, "paquicefalo.png"))
    gravar(os.path.join(SAIDA, "favicon.png"), [linha[:32] for linha in p[:32]])


if __name__ == "__main__":
    main()
