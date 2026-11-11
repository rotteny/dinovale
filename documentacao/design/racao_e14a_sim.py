#!/usr/bin/env python3
"""E14a (Racao): tempo de domar, refeicoes, torpor e Eficiencia com a formula unica da 5.14. Biblioteca padrao.
Uso: python3 racao_e14a_sim.py tabela|dodo|utah|tric|nos|peso   (proposta 10/11, provisoria)
Premissas lidas do codigo em 10/11: queda de torpor dormindo 1,0/s GLOBAL (TorporComponent), Bastao 30 de torpor a cada 0,7 s,
perda de Eficiencia por golpe do jogador dormindo = 4 + 0,5 x % da vida maxima perdida (taming_rules.tres), Bastao dano 2."""
import math, sys
SLOPE, FLOOR, L0 = 0.033, 0.5, 10          # dino_level_rules.tres: meals_slope 0,015 -> 0,033; meals_floor 0,85 -> 0,5
DRAIN_T = 0.15                              # eficiencia_drena_tempo (era 0,3)
DECAY = 1.0                                 # torpor/s dormindo, global
HIT_T, HIT_CD, HIT_DMG = 30.0, 0.7, 2.0     # Bastao
# grau: multiplicador de refeicoes sobre base_meals 10, intervalo s, dreno de Eficiencia por refeicao, agitacao (torpor por refeicao)
G = {"crua": dict(m=1.0, iv=6.0, dm=2.0, ag=5.0), "C": dict(m=0.8, iv=5.0, dm=1.5, ag=3.0),
     "B": dict(m=0.6, iv=5.0, dm=1.0, ag=2.0), "A": dict(m=0.5, iv=4.0, dm=0.5, ag=1.5)}
ORDER = ["crua", "C", "B", "A"]
# especie: dificuldade, bocado, torpor base, vida base, racao_minima (grau), aceita crua, [niveis]
SP = {"Dodo": dict(d=0.6, bite=1, tor=50, hp=24, mn="C", raw=True, lv=(3, 10, 20)),
      "Paquicefalo": dict(d=1.5, bite=1, tor=100, hp=100, mn="C", raw=True, lv=(5, 10, 20)),
      "Utahraptor": dict(d=1.5, bite=1, tor=120, hp=80, mn="B", raw=True, lv=(10, 15, 25)),
      "Triceratops": dict(d=1.7, bite=3, tor=160, hp=300, mn="A", raw=False, lv=(18, 21, 24))}
def lf(L): return max(FLOOR, 1 + SLOPE * (L - L0))
def mtor(L): return max(0.7, 1 + 0.02 * (L - L0))
def mhp(L): return max(0.5, 1 + 0.04 * (L - L0))
def final_level(L, E):
    return max(min(math.floor(L * (1 + 0.5 * E / 100) + 0.5 + 1e-9), math.floor(1.5 * L + 0.5 + 1e-9)), L)
def tame(sp, g, L, rate=1.0, agit=True, mn=None):
    s = SP[sp]; q = G[g]; mn = mn or s["mn"]
    below = g != "crua" and ORDER.index(g) < ORDER.index(mn)
    meals = max(1, math.ceil(10 * q["m"] * s["d"] * lf(L) - 1e-9))
    eaten = meals * (2 if below else 1)                    # abaixo da minima: cada refeicao vale metade
    t = eaten * q["iv"] * s["bite"] / rate
    tmax = s["tor"] * mtor(L)
    need = t * DECAY + (eaten * q["ag"] if agit else 0)
    extra = max(0.0, need - tmax)
    hits = math.ceil(extra / HIT_T - 1e-9)
    loss = 4 + 0.5 * 100 * HIT_DMG / (s["hp"] * mhp(L))
    E = max(0.0, 100 - DRAIN_T * t - q["dm"] * eaten - hits * loss)
    return dict(meals=meals, eaten=eaten, t=t, tmax=tmax, need=need, extra=extra, hits=hits, E=E, lv=final_level(L, E), below=below)
def tabela(agit=True):
    print(f"agitacao {'LIGADA' if agit else 'zero'}; torpor/s dormindo {DECAY}; dreno de tempo {DRAIN_T}")
    print(f"{'especie':12}{'L':>3} {'grau':5}{'refeic':>7}{'rac':>5}{'tempo':>8}{'janela':>8}{'extra':>7}{'Bastao':>7}{'E':>5}{'nivel':>8}  obs")
    for sp, s in SP.items():
        for L in s["lv"]:
            for g in ORDER:
                if g == "crua" and not s["raw"]: continue
                r = tame(sp, g, L, agit=agit)
                print(f"{sp:12}{L:>3} {g:5}{r['meals']:>7}{r['eaten']:>5}{r['t']:>7.0f}s{r['tmax']:>7.0f}s{r['extra']:>7.0f}{r['hits']:>7}{r['E']:>5.0f}{L:>4}->{r['lv']:<3} {'abaixo da minima' if r['below'] else ''}")
def dodo():
    print("Dodo, formula nova (10 x 0,6 x fator), crua 6 s, comparado ao codigo de hoje (0,015, piso 0,85, 5 s)")
    for L in (3, 6, 10, 15, 20):
        new = math.ceil(10 * 0.6 * lf(L) - 1e-9); old = math.ceil(10 * 0.6 * max(0.85, 1 + 0.015 * (L - 10)) - 1e-9)
        r = tame("Dodo", "crua", L, agit=True); r0 = tame("Dodo", "crua", L, agit=False)
        print(f"  L{L:<3} refeicoes novo {new} (codigo {old}); tempo {new*6}s; janela {r['tmax']:.0f}s; extra com agitacao {r['extra']:.0f} ({r['hits']} Bastao), sem {r0['extra']:.0f}; E {r['E']:.0f}")
    print("Paquicefalo, GDD (10 x 1,5, 6 s) contra o codigo de hoje (5 x 1,0, 5 s)")
    for L in (5, 8, 10, 20):
        new = math.ceil(10 * 1.5 * lf(L) - 1e-9); old = math.ceil(5 * 1.0 * max(0.85, 1 + 0.015 * (L - 10)) - 1e-9)
        r = tame("Paquicefalo", "crua", L)
        print(f"  L{L:<3} refeicoes {new} x 6 s = {new*6}s (codigo hoje {old} x 5 s = {old*5}s); janela {r['tmax']:.0f}s; extra {r['extra']:.0f} = {r['hits']} Bastao")
def utah():
    L = 15
    print(f"Utahraptor L{L}: teste do dono, 25 carne (carne por receita: C 3, B 2+1 tuberculo, A 2+1 tuberculo+1 sal, rende 2; crua = 1 carne por refeicao)")
    for g in ORDER:
        r = tame("Utahraptor", g, L)
        if g == "crua": print(f"  crua  {r['eaten']} refeicoes, {r['eaten']} carne, {r['t']:.0f}s ({r['t']/60:.1f} min), janela {r['tmax']:.0f}s, extra {r['extra']:.0f} = {r['hits']} Bastao, E {r['E']:.0f} -> nivel {r['lv']}"); continue
        need_r = r["eaten"]; crafts = math.ceil(need_r / 2)
        carne = crafts * {"C": 3, "B": 2, "A": 2}[g]; tub = crafts if g in "BA" else 0; sal = crafts if g == "A" else 0
        print(f"  {g:5} {r['eaten']} racoes ({r['meals']} refeicoes{', abaixo da minima: metade' if r['below'] else ''}), {crafts} fabricacoes = {carne} carne + {tub} tuberculo + {sal} sal; {r['t']:.0f}s ({r['t']/60:.1f} min), extra {r['extra']:.0f} = {r['hits']} Bastao, E {r['E']:.0f} -> nivel {r['lv']}; sobra de 25 carne: {25-carne}")
    print("  com min C (alternativa): C Rubra nao fica abaixo, 14 racoes, 70 s")
def tric():
    for L in (18, 21, 24):
        for g in ("C", "B", "A"):
            r = tame("Triceratops", g, L)
            crafts = math.ceil(r["eaten"] / 2)
            print(f"  Tric L{L} {g}: {r['eaten']} racoes, {crafts} fabr., {r['t']:.0f}s ({r['t']/60:.1f} min), extra {r['extra']:.0f} = {r['hits']} Bastao, E {r['E']:.0f} {'(abaixo da minima A)' if r['below'] else ''}")
def nos():
    esc = {"C": 4.33, "M": 4.10, "P": 3.47}
    tub = round(8 * esc["C"]) + round(4 * esc["M"]); sal = round(8 * esc["P"])
    print(f"tuberculo: {round(8*esc['C'])} Campina + {round(4*esc['M'])} Mata = {tub} nos x 2 = {tub*2} por ciclo de 420 s = {tub*2/7:.1f}/min; sal: {sal} nos x 2 = {sal*2} por 480 s = {sal*2/8:.1f}/min")
    print("fabricacao A: 1 tuberculo + 1 sal por 2 racoes. Triceratops L21 com A: 12 racoes = 6 tuberculos + 6 sal = 3 nos de sal; Utahraptor L15 com B: 6 tuberculos")
    print(f"quantas domas de Triceratops por ciclo de sal ({sal*2} sal): {sal*2/6:.1f}; de tuberculo B para Utahraptor ({tub*2}): {tub*2/6:.1f}")
def peso():
    for sp, L, g, f in (("Utahraptor", 15, "crua", 0.5), ("Utahraptor", 15, "C", 0.2), ("Utahraptor", 15, "B", 0.2), ("Utahraptor", 15, "A", 0.2),
                        ("Paquicefalo", 10, "crua", 0.1), ("Paquicefalo", 10, "C", 0.2), ("Paquicefalo", 10, "A", 0.2),
                        ("Triceratops", 21, "A", 0.2), ("Triceratops", 21, "C", 0.2)):
        r = tame(sp, g, L, mn="C" if sp == "Triceratops" and g == "C" else None)
        print(f"  {sp:12} L{L} {g:5} {r['eaten']:>3} unidades x {f} kg = {r['eaten']*f:5.1f} kg")
if __name__ == "__main__":
    a = sys.argv[1]
    {"tabela": tabela, "dodo": dodo, "utah": utah, "tric": tric, "nos": nos, "peso": peso}[a]() if a != "tabela0" else tabela(False)
