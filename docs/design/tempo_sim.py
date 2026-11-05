#!/usr/bin/env python3
"""Tempo de domar (Dino Vale), calibrado para alvos proprios em minutos. Biblioteca padrao.
Uso: python3 tempo_sim.py tabela|torpor|eficiencia|curral|carne|hora"""
import math, sys
from racao_sim import Q
from nivel_sim import m_tor, final_level, attack_loss, DRAIN_M, HIT, CD
SP = {  # d: refeicoes x; ivf: tempo por refeicao x; mx torpor no nivel 10; dec queda/s; food: comida-base
 "Paquicefalo": dict(d=1.5, ivf=1, mx=100, dec=1.0, base="Baga", lv=(5, 10, 20)),
 "Utahraptor": dict(d=1.5, ivf=1, mx=120, dec=1.2, base="Baga", lv=(10, 15, 25)),   # carne crua no grau da baga
 "Parassaurolofo": dict(d=1.1, ivf=1, mx=140, dec=1.3, base="Baga", lv=(10, 20, 30)),
 "Triceratops": dict(d=1.7, ivf=3, mx=160, dec=1.5, base="C", lv=(20, 28, 40)),     # sem baga: parte da Racao C
}
RATE = 1.0   # taxa padrao do servidor (domar_velocidade); tempo = t / RATE
def m_t(L): return max(0.5, 1 + 0.033 * (L - 10))     # refeicoes por nivel (era 0,015, piso 0,85)
def tame(sp, q, L, rate=RATE):
    s = SP[sp]; qq = Q[q]
    meals = math.ceil(qq["meals"] * s["d"] * m_t(L) - 1e-9)
    t = meals * qq["iv"] * s["ivf"] / rate
    mx = s["mx"] * m_tor(L)
    need = t * s["dec"] + meals * qq["agit"]
    return dict(meals=meals, t=t, mx=mx, need=need)
def tabela():
    print(f"{'especie':15}{'nivel':>6}  {'comida':8}{'qtd':>4}{'tempo':>9}   | com Racao A: qtd, tempo")
    for sp, s in SP.items():
        for L in s["lv"]:
            r = tame(sp, s["base"], L); a = tame(sp, "A", L)
            nm = {"Baga": "baga/carne", "C": "Racao C"}[s["base"]]
            print(f"{sp:15}{L:>6}  {nm:10}{r['meals']:>3}{r['t']/60:>7.1f} min   | {a['meals']:>3}, {a['t']/60:.1f} min")
def torpor():
    print("manter dormindo: torpor extra = tempo x queda + refeicoes x agitacao - torpor maximo")
    for sp, s in SP.items():
        for L in s["lv"]:
            for q in (s["base"], "A"):
                r = tame(sp, q, L); ex = max(0, r["need"] - r["mx"])
                hb = math.ceil(ex / HIT); hs = math.ceil(ex / 10)
                print(f"{sp:15} L{L:<3}{q:5} janela {r['mx']/s['dec']:4.0f}s tempo {r['t']:4.0f}s extra {ex:5.0f} | Bastao {hb:2} golpes {hb*CD:4.1f}s | Soco {hs:2} golpes {hs*0.6:4.1f}s | fruta {ex*0.133:4.0f}s")
def eficiencia():
    print("E = 100 - dreno_tempo x t - dreno_refeicao x refeicoes - golpes x perda; dreno_tempo 0,3 (atual) e 0,15 (recomendado)")
    for sp, s in SP.items():
        L = s["lv"][1]
        for q in (s["base"], "B", "A"):
            r = tame(sp, q, L); ex = max(0, r["need"] - r["mx"]); h = math.ceil(ex / HIT)
            perda = attack_loss(sp.replace("ç", "c"), L, "jogador")[0]
            out = []
            for dr in (0.3, 0.15):
                E = max(0, min(100, 100 - dr * r["t"] - DRAIN_M[q] * r["meals"] - h * perda))
                out.append(f"dreno {dr}: E {E:3.0f} nivel {L}->{final_level(L, E)}")
            print(f"{sp:15} L{L:<3}{q:5} {r['t']:4.0f}s, {h} golpes de Bastao | " + " | ".join(out))
def curral():
    print("Utahraptor: tempo de domar por nivel e Racao (cerca de madeira cede em 8 s; 16 s com duas camadas)")
    for L in (10, 15, 25):
        print(f"  L{L}: " + ", ".join(f"{q} {tame('Utahraptor', q, L)['t']:.0f}s" for q in ("Baga", "C", "B", "A")))
def carne():
    print("Utahraptor L15: refeicoes e carne [carne = refeicoes x 1,75 (C), 1,0 (B), 1,1 (A): proporcao da conta anterior]")
    f = {"C": 1.75, "B": 1.0, "A": 1.1}
    for q in ("C", "B", "A"):
        r = tame("Utahraptor", q, 15); c = math.ceil(r["meals"] * f[q])
        print(f"  {q}: {r['meals']} refeicoes, ~{c} carne = {math.ceil(c/2)} Dodos ({math.ceil(c/2)*30/60:.1f} min de caca), validade 30 min: margem {30/(math.ceil(c/2)*30/60):.1f}x")
def hora():
    for L in (5, 8, 12):
        r = tame("Paquicefalo", "Baga", L); ex = max(0, r["need"] - r["mx"]); h = math.ceil(ex / HIT)
        print(f"Paquicefalo L{L}: {r['meals']} bagas, {r['t']:.0f}s dormindo, coleta {r['meals']*3:.0f}s, extra {ex:.0f} torpor = {h} golpes de Bastao ou {math.ceil(ex/10)} de Soco; nocaute inicial 4 golpes (Bastao) ou 15 (Soco)")
{"tabela": tabela, "torpor": torpor, "eficiencia": eficiencia, "curral": curral, "carne": carne, "hora": hora}[sys.argv[1]]()
