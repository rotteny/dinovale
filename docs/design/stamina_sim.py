#!/usr/bin/env python3
"""Stamina em golpes e coleta (Dino Vale). Biblioteca padrao. [premissa] = valor a testar.
Uso: python3 stamina_sim.py custos|luta|coleta|valor"""
import sys, math
MAX, REGEN, SPRINT, RESUME, DELAY = 100.0, 15.0, 25.0, 20.0, 0.5   # reais, exceto DELAY
CUSTO_GOLPE = {"Soco": (3, 0.6), "Bastao-de-sono": (6, 0.7), "Dardo (arremesso)": (4, 1.0)}   # stamina por golpe, cooldown
CUSTO_COLETA = {"maos: madeira e pedra": 4, "machado/picareta": 3, "maos: baga, fibra, fruta, carcaca": 2}   # por segundo de acao
PEN_CD, PEN_EFEITO = 1.5, 0.75       # sem stamina: cooldown x1,5 e efeito x0,75 (golpe); coleta x1,5 de tempo; nunca bloqueia
def maxs(p): return MAX * (1 + 0.06 * p)
def custos():
    for n, (c, cd) in CUSTO_GOLPE.items(): print(f" {n:20} {c} por golpe, cd {cd} s = {c/cd:4.1f}/s; golpes ate esgotar: {MAX/c:4.1f}")
    for n, c in CUSTO_COLETA.items(): print(f" coleta {n:35} {c}/s: {MAX/c:4.0f} s ate esgotar")
    print(f" regen {REGEN}/s so apos {DELAY} s sem agir; sprint {SPRINT}/s ({MAX/SPRINT:.0f} s); retoma com {RESUME} (1,3 s parado)")
def luta():
    print("Nocaute com Bastao (30 torpor, queda acordada 5/s). Utahraptor L20 (torpor 144, mordida 11,2/1,5 s), Triceratops L28 (218; 34,4/2,5 s)")
    print("'fresco' = comeca com stamina cheia; 'pos-sprint' = correu 4 s antes de bater")
    for nome, T, D, dcd in (("Utahraptor L20", 144, 11.2, 1.5), ("Triceratops L28", 218, 34.4, 2.5)):
        print(f" {nome}")
        for pts in (0, 6, 10, 19):
            for estado in ("fresco", "pos-sprint"):
                m = maxs(pts); s = m if estado == "fresco" else max(0.0, m - SPRINT * 4)
                tor, t, n, cus = 0.0, 0.0, 0, 6
                while tor < T:
                    if n: t += 0.7 * (PEN_CD if s < cus else 1.0)
                    ef = 1.0 if s >= cus else PEN_EFEITO
                    tor = max(0.0, tor - 5 * (0.7 if n else 0)) if False else tor
                    tor += 30 * ef
                    if n: tor -= 5 * (0.7 * (PEN_CD if s < cus else 1.0))
                    s = max(0.0, s - cus); n += 1
                bites = int(t // dcd)
                print(f"   {pts:2} pts Stamina ({m:3.0f}) {estado:10}: {n:2} golpes, {t:5.1f} s, {bites} mordidas = {bites*D:5.1f} dano")
    print(" Regra de bolso: sprint de 4 s (100) + 6 golpes (36) = 136 -> 6 pontos de Stamina; Triceratops 9 golpes (54) -> sprint + golpes = 154 -> 9 pontos")
def coleta():
    print("Coleta continua, regen so parado. Madeira por maos (3 madeira = 8 s, 4/s = 32 por no) e machado (5,2 s, 3/s = 15,6)")
    for nome, c, t0 in (("maos", 4, 8.0), ("machado", 3, 5.2)):
        for pts in (0, 10):
            s, tempo = maxs(pts), 0.0
            for no in range(10):
                gasto = c * t0
                if s >= gasto: s -= gasto; tempo += t0
                else: tempo += (s / c) + (t0 - s / c) * PEN_CD; s = 0
            print(f"   {nome:8} {pts:2} pts: 10 nos seguidos em {tempo:5.1f} s (ideal {10*t0:4.0f} s) sem pausar")
    print(" Duty cycle sustentavel: regen/(regen+custo): maos 15/19 = 79%; machado 15/18 = 83%; exaurido roda a 1/1,5 = 67%: a diferenca e pequena -> coleta nunca espera, so desacelera")
    print(" Carcaca de 57 s a 2/s = 114: esgota aos 50 s, +3,5 s = 60,5 s; com 3 pontos (118) nao esgota. Valor do ponto na coleta: ~3 s por carcaca grande.")
def valor():
    print("O que 1 ponto de Stamina (+6 de max) compra [calculado]")
    for p in (1, 6, 10, 19):
        print(f"   {p:2} pts: max {maxs(p):3.0f}; sprint {maxs(p)/SPRINT:4.1f} s; golpes de Bastao ate esgotar {maxs(p)/6:4.1f}; nos de madeira a mao {maxs(p)/32:3.1f}; folga apos sprint+Utahraptor (136): {maxs(p)-136:+4.0f}")
    print("   Vida: 6 pts = +36 HP = 3,2 mordidas de Utahraptor L20; Stamina 6 pts = sprint +1,4 s (+42 px de folga ~2,6 tiles) e luta sem esgotar apos correr")
{"custos": custos, "luta": luta, "coleta": coleta, "valor": valor}[sys.argv[1]]()
