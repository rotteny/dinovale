#!/usr/bin/env python3
"""Nível e Eficiência do Dino Vale. Python puro. python3 nivel_sim.py [niveis|eficiencia|preco|golpes]"""
import math, sys
from racao_sim import Q, SP, ration_cost, GATHER

L0 = 10
def m_stat(L):   return max(0.5, 1 + 0.04 * (L - L0))   # vida, dano, ofício base
def m_tor(L):    return max(0.7, 1 + 0.02 * (L - L0))   # torpor máximo
def m_tempo(L):  return max(0.85, 1 + 0.015 * (L - L0)) # refeições (tempo e comida)
def m_peso(L):   return max(0.7, 1 + 0.03 * (L - L0))   # Peso (capacidade de carga)
def m_stam(L):   return max(0.7, 1 + 0.02 * (L - L0))   # Stamina do dino: RESERVADA (M4+, montaria); sem uso na 0.2
# Velocidade: fixa por espécie (sem fórmula). Fome: medidor sem crescimento.
PESO_BASE = {'Paquicefalo': 40, 'Utahraptor': 0, 'Parassaurolofo': 100, 'Triceratops': 120, 'Gallimimus': 25}  # kg no nível 10
PESO_JOGADOR = 50.0  # kg, fixo no MVP (sem nível)
DRAIN_T = 0.3                   # E por segundo dormindo
DRAIN_M = {"Baga": 2.0, "C": 1.5, "B": 1.0, "A": 0.5, "S": 0.0, "S+": -2.0}  # E por refeição
DART_E = 2.0                    # E por dardo (sedação forçada); dardo = dose de 50 torpor (10 imediato + 8/s x 5 s), 0 dano
ATK_FLAT = {"jogador": 4.0, "carnivoro": 8.0}  # E fixo por ataque recebido dormindo
DMG_E = 0.5                     # E por 1% de vida máxima perdida em dano (só dormindo)
PLAYER_HIT_DMG = 2.0; BITE_BASE = 8.0; BITE_L = 15; BITE_CD = 1.5
HP = {"Paquicefalo": 80, "Utahraptor": 80, "Parassaurolofo": 200, "Triceratops": 300, "Gallimimus": 70}
HIT = 30.0; CD = 0.7; DECAY_AWAKE = 5.0

def final_level(L, E):          # E em 0..100; arredonda para o mais próximo, meio para cima; teto 1,5x
    return min(math.floor(L * (1 + 0.5 * E / 100) + 0.5), math.floor(L * 1.5 + 0.5))

def attack_loss(sp, L, kind):
    hp = HP[sp] * m_stat(L)
    dmg = PLAYER_HIT_DMG if kind == "jogador" else BITE_BASE * m_stat(BITE_L)
    return ATK_FLAT[kind] + DMG_E * 100 * dmg / hp, dmg / hp * 100

def taming(q, sp, L, topups=0, bites=0, hits=0):
    s = SP[sp]; qq = Q[q]
    meals = math.ceil(qq["meals"] * s["d"] * m_tempo(L) - 1e-9)
    t = meals * qq["iv"]; mx = s["mx"] * m_tor(L)
    need = t * s["dec"] + meals * qq["agit"]
    E = 100 - DRAIN_T * t - DRAIN_M[q] * meals - DART_E * topups - bites * attack_loss(sp, L, "carnivoro")[0] - hits * attack_loss(sp, L, "jogador")[0]
    E = max(0.0, min(100.0, E))
    return dict(meals=meals, t=t, mx=mx, janela=mx / s["dec"], need=need, pct=need / mx, E=E, lv=final_level(L, E))

def hits_to_ko(mx):
    n = 0; tor = 0.0
    while tor < mx:
        n += 1; tor += HIT
        if tor >= mx: break
        tor -= DECAY_AWAKE * CD
    return n

if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "niveis"
    if mode == "niveis":
        print("L   vida/dano  torpor  tempo  peso   stam(res.) | golpes(torpor 100 / 160)")
        for L in (1, 5, 10, 20, 30, 40, 60):
            print(f"{L:3} {m_stat(L):8.2f} {m_tor(L):6.2f} {m_tempo(L):6.2f} {m_peso(L):6.2f} {m_stam(L):8.2f} | {hits_to_ko(100*m_tor(L))}  {hits_to_ko(160*m_tor(L))}")
        print("\nVida por nível (Paquicefalo, Utahraptor, Parassaurolofo, Triceratops, Gallimimus):")
        for L in (5, 10, 20, 30, 40):
            print(L, [round(h * m_stat(L)) for h in HP.values()])
        print("\nPeso por espécie (kg): L10 / L20 / L30")
        for sp, b in PESO_BASE.items(): print(f"  {sp:15} {b*m_peso(10):6.1f} {b*m_peso(20):6.1f} {b*m_peso(30):6.1f}")
        print(f"  Jogador (sem nível): {PESO_JOGADOR} kg")
        print("\nArredondamento (L, E) -> nível final:", [(L, E, final_level(L, E)) for L, E in ((20,100),(20,99),(20,75),(20,50),(20,0),(7,100),(7,60),(1,100),(60,100))])
    elif mode == "eficiencia":
        cases = [("bom", 0, 0), ("médio", 1, 2), ("ruim", 2, 5)]
        for sp, L in (("Paquicefalo", 8), ("Utahraptor", 15), ("Parassaurolofo", 20), ("Triceratops", 28)):
            print(f"\n{sp} nível selvagem {L}")
            print("qual   refeições tempo janela torpor%  | E bom/médio/ruim            | nível final bom/médio/ruim")
            for q in Q:
                if q == "Baga" and not SP[sp]["baga"]: continue
                r = [taming(q, sp, L, tp, bt) for _, tp, bt in cases]
                print(f"{q:5} {r[0]['meals']:6} {r[0]['t']:6.0f} {r[0]['janela']:6.0f} {r[0]['pct']*100:6.0f}% | " + "/".join(f"{x['E']:5.1f}" for x in r) + " | " + "/".join(str(x['lv']) for x in r))
    elif mode == "preco":
        print("Preço implícito: segundos de coleta extra por nível ganho; abaixo disso o nível mais caro compensa")
        for sp, L in (("Paquicefalo", 8), ("Utahraptor", 15), ("Parassaurolofo", 20), ("Triceratops", 28)):
            base = None
            print(f"\n{sp} L{L} (médio: 1 dardo e 2 mordidas)")
            prev = None
            for q in [x for x in Q if not (x == "Baga" and not SP[sp]["baga"])]:
                r = taming(q, sp, L, 1, 2); coleta = r["meals"] * ration_cost(q, sp) + r["t"]  # expõe t com k=1
                if prev:
                    dl = r["lv"] - prev[1]; dc = coleta - prev[2]
                    print(f"{prev[0]}->{q}: +{dc:5.0f} s, {dl:+d} níveis (final {r['lv']})  " + (f"{dc/dl:6.1f} s/nível" if dl > 0 else "sem ganho"))
                prev = (q, r["lv"], coleta)

    if mode == "ataques":
        print("Ataque ao dormindo: E por ataque, dano em % da vida, e tempo até E=0 / até morrer (mordida a cada 1,5 s)")
        for sp, L in (("Paquicefalo", 8), ("Utahraptor", 15), ("Parassaurolofo", 20), ("Triceratops", 28)):
            for kind in ("jogador", "carnivoro"):
                e, pct = attack_loss(sp, L, kind)
                n_e0 = math.ceil(100 / e); n_dead = math.ceil(100 / pct)
                print(f"{sp:13} L{L:2} {kind:9} E/ataque={e:5.1f} vida/ataque={pct:5.1f}%  ataques até E=0: {n_e0:3}  até morrer: {n_dead:3}  (carnívoro: E=0 em {n_e0*BITE_CD:5.1f} s, morte em {n_dead*BITE_CD:5.1f} s)")
        print("\nPior caso de reação R (s até o jogador afastar o carnívoro): E restante e se morre")
        for sp, L in (("Paquicefalo", 8), ("Utahraptor", 15), ("Parassaurolofo", 20), ("Triceratops", 28)):
            e, pct = attack_loss(sp, L, "carnivoro")
            row = []
            for R in (2, 4, 8, 12):
                n = math.floor(R / BITE_CD) + 1  # primeira mordida em t=0
                row.append(f"R={R:2}s: {n} mordidas, E-{min(100,n*e):5.1f}, vida-{min(100,n*pct):5.1f}%{' MORRE' if n*pct>=100 else ''}")
            print(sp, "|", " | ".join(row))
