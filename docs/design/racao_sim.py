#!/usr/bin/env python3
"""Simulação da Ração do Dino Vale. Perfil Mista reservado ao M4 (Oviraptor); no MVP, Verde e Rubra. Python puro. Uso: python3 racao_sim.py [tabela|mc|custo|afeto]"""
import math, random, sys

# --- Dados (espelham a seção 2 do doc) -------------------------------------
# qualidade: refeições base (d=1), intervalo s, agitação (torpor perdido por refeição), afeto inicial
Q = {
 "Baga": dict(meals=10, iv=6.0, agit=5.0, afeto=0),
 "C":    dict(meals=8,  iv=5.0, agit=3.0, afeto=0),
 "B":    dict(meals=6,  iv=5.0, agit=2.0, afeto=5),
 "A":    dict(meals=5,  iv=4.0, agit=1.5, afeto=10),
 "S":    dict(meals=4,  iv=4.0, agit=1.0, afeto=20),
 "S+":   dict(meals=3,  iv=4.0, agit=0.5, afeto=30),
}
# espécie: dificuldade d, torpor máx, queda inconsciente/s, aceita baga, perfil base
SP = {
 "Paquicefalo":  dict(d=1.0,  mx=100, dec=1.0, baga=True,  base="verde"),
 "Utahraptor":  dict(d=1.5,  mx=120, dec=1.2, baga=False, base="rubra"),
 "Parassaurolofo": dict(d=1.5, mx=140, dec=1.3, baga=True,  base="verde"),
 "Triceratops":  dict(d=2.0,  mx=160, dec=1.5, baga=False, base="verde"),
 "Dodo":         dict(d=0.7,  mx=50,  dec=0.8, baga=True,  base="verde"),   # Covarde de grupo, domavel (06/11)
 "Listro":       dict(d=0.8,  mx=48,  dec=0.9, baga=True,  base="verde"),   # M4, domavel
 "Gallimimus":   dict(d=1.25, mx=100, dec=1.2, baga=True,  base="verde"),
}
DART = 50.0   # dose total do dardo: 10 imediato + 8/s x 5 s (06/11)
AFETO_S = 1.0  # 1 ponto de afeto inicial vale 2 s de coleta (premissa)
# segundos de coleta por unidade (premissa a validar jogando)
GATHER = dict(baga=3, samambaia=4, carne=8, tuberculo=8, sal=10, mel=25, seiva=30)
BASEUNIT = dict(verde=(GATHER["baga"]+GATHER["samambaia"])/2,
                rubra=GATHER["carne"],
                mista=(2*(GATHER["baga"]+GATHER["samambaia"])/2+GATHER["carne"])/3)
# adicionais por qualidade (unidades) ; receita: 2 base + adicionais ; rende 2 rações
ADD = {"C": dict(base=3), "B": dict(base=2, tuberculo=1), "A": dict(base=2, tuberculo=1, sal=1),
       "S": dict(base=2, sal=1, mel=1), "S+": dict(base=2, mel=1, seiva=2)}
YIELD_Q = {"C": 2, "B": 2, "A": 2, "S": 2, "S+": 2}  # rações por craft
CRAFT_S = 4.0  # segundos por craft na bancada comum

def meals_needed(q, sp):
    return math.ceil(Q[q]["meals"] * SP[sp]["d"] - 1e-9)

def ration_cost(q, sp):
    if q == "Baga": return GATHER["baga"]
    a = ADD[q]; c = a["base"] * BASEUNIT[SP[sp]["base"]]
    for k, v in a.items():
        if k != "base": c += v * GATHER[k]
    y = YIELD_Q[q]; return c / y + CRAFT_S / y

def det(q, sp):
    s = SP[sp]; m = meals_needed(q, sp); t = m * Q[q]["iv"]
    need = t * s["dec"] + m * Q[q]["agit"]
    return m, t, need, need / s["mx"]

# --- Monte Carlo ------------------------------------------------------------
def run(q, sp, lam, darts, stock_delta=0, rng=random, fight=10.0, wake_p=0.15):
    s = SP[sp]; qq = Q[q]; m = meals_needed(q, sp); stock = m + stock_delta
    tor = s["mx"]; prog = 0; t = 0.0; clock = 0.0; busy = 0.0; used = 0; dt = 0.1; used_darts = 0
    while True:
        t += dt; clock += dt
        tor -= s["dec"] * dt
        if busy > 0: busy -= dt
        if rng.random() < lam * dt:
            busy = fight
            if rng.random() < wake_p: return False, t, used, used_darts, "invasor"
        if tor <= 0: return False, t, used, used_darts, "acordou"
        if busy <= 0 and darts > 0 and tor < 22:   # política: dardo quando abaixo de 22
            tor = min(s["mx"], tor + DART); darts -= 1; used_darts += 1
        if clock >= qq["iv"] and stock > used:
            clock -= qq["iv"]; used += 1; prog += 1; tor -= qq["agit"]
            if prog >= m: return True, t, used, used_darts, "ok"
        if stock <= used and prog < m and t > 400: return False, t, used, used_darts, "sem ração"

def mc(n=4000, seed=7):
    cases = {"bom": (1/400, 3, 0), "medio": (1/150, 2, 0), "ruim": (1/60, 1, 0)}
    out = []
    for sp in SP:
        for q in Q:
            if q == "Baga" and not SP[sp]["baga"]: continue
            for cn, (lam, dr, sd) in cases.items():
                r = random.Random(seed); ok = 0; T = 0; used = 0; dart = 0
                for _ in range(n):
                    a, t, u, d, _ = run(q, sp, lam, dr, sd, r)
                    ok += a; T += t; used += u; dart += d
                out.append((sp, q, cn, ok/n, T/n, used/n, dart/n))
    return out

if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "tabela"
    if mode == "tabela":
        print("Custo de coleta por ração (s):", {q: round(ration_cost(q, 'Paquicefalo'),1) for q in Q})
        for sp in SP:
            print(f"\n{sp} (d={SP[sp]['d']}, torpor {SP[sp]['mx']}, queda {SP[sp]['dec']}/s, janela {SP[sp]['mx']/SP[sp]['dec']:.0f} s)")
            print("qual  refeições  tempo(s)  torpor_gasto  %janela  dardos_min  coleta_total(s)")
            for q in Q:
                if q == "Baga" and not SP[sp]["baga"]: continue
                m, t, need, r = det(q, sp)
                darts = max(0, math.ceil((need - SP[sp]["mx"]) / DART))
                print(f"{q:5} {m:8} {t:9.0f} {need:12.0f} {r*100:7.0f}% {darts:8} {m*ration_cost(q, sp):12.0f}")
    elif mode == "mc":
        print("especie qual caso sucesso tempo_medio rações dardos")
        for r in mc(): print(f"{r[0]:13} {r[1]:4} {r[2]:6} {r[3]*100:5.1f}% {r[4]:6.1f}s {r[5]:5.1f} {r[6]:4.2f}")
    elif mode == "custo":
        # custo esperado por domesticação concluída: coleta de tudo que foi consumido (inclui tentativas falhas)
        # + k * segundos expostos; afeto vira segundos (1 afeto = 20 s, premissa)
        cases = {"bom": (1/400, 3, 0), "medio": (1/150, 2, 0), "ruim": (1/60, 1, 0)}
        for k in (1, 3, 6):
            print(f"\n== k={k}; afeto={AFETO_S} s/ponto ==")
            for sp in SP:
                for cn, (lam, dr, sd) in cases.items():
                    row = []
                    for q in Q:
                        if q == "Baga" and not SP[sp]["baga"]: continue
                        r = random.Random(3); tot = 0; succ = 0; n = 3000
                        for _ in range(n):
                            a, t, u, d, _ = run(q, sp, lam, dr, sd, r)
                            tot += u * ration_cost(q, sp) + k * t + d * 6   # dardo ~6 s de coleta
                            succ += a
                        e = tot / max(succ, 1) - Q[q]["afeto"] * AFETO_S
                        row.append((e, q, succ / n))
                    best = min(row)
                    print(f"{sp:13} {cn:6} " + "  ".join(f"{q}:{e:5.0f}" for e, q, _ in row) + f"   melhor={best[1]}")
