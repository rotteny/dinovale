#!/usr/bin/env python3
"""v0.2 sem dardo, sem Oferta, sem Listro: Parassaurolofo (foge) e Triceratops (investe) com Bastao e Soco. Biblioteca padrao.
Uso: python3 medroso_sim.py para|tri"""
import sys, math
WALK, SPRINT, STAM, DRAIN, REGEN, RESUME = 70.0, 120.0, 100.0, 25.0, 15.0, 20.0
REACH, DECAY = 24.0, 5.0
ARMAS = {"Bastao": (30.0, 0.7, 6.0), "Soco": (10.0, 0.6, 3.0)}      # torpor, recarga, Stamina por golpe
def m_tor(L): return max(0.7, 1 + 0.02 * (L - 10))
def band(f): return 1.0 if f < .5 else (0.85 if f < .75 else 0.65)
def run(vf, tmax, arma, hesit=0.8, sprint=True, gap0=20.0, flee_tiles=16.0):
    hit, cdv, scost = ARMAS[arma]; dt = .01; t = 0; gap = gap0; tor = 0.0; stam = STAM; blocked = False; cd = 0; hits = 0; first = None; fled = 0.0; stam_min = STAM; exh = False
    while t < 40:
        t += dt; cd = max(0, cd - dt); tor = max(0, tor - DECAY * dt); f = tor / tmax
        vd = 0.0 if (first is not None and t - first < hesit) else vf * band(f)
        if first is not None and f >= .75 and int(t / 0.8) % 5 == 4: vd = 0.0
        if fled / 16.0 >= flee_tiles: vd = 0.0          # a fuga acaba aos 16 tiles
        vp = SPRINT if (sprint and not blocked and stam > 0) else WALK
        stam = stam - DRAIN * dt if vp == SPRINT else min(STAM, stam + REGEN * dt)
        if stam <= 0: blocked = True; exh = True
        if blocked and stam >= RESUME: blocked = False
        gap = max(0.0, gap + (vd - vp) * dt); fled += vd * dt
        if gap <= REACH and cd == 0:
            tor += hit; hits += 1; cd = cdv * (1.5 if exh and stam < RESUME else 1.0); stam -= scost
            stam_min = min(stam_min, stam)
            if first is None: first = t
            if tor >= tmax: return True, t, hits, fled / 16.0, stam_min
    return False, t, hits, fled / 16.0, stam_min
def para():
    print("Parassaurolofo (Medroso): 1o golpe de perto, susto 0,8 s, foge ao fim a 16 tiles")
    print(f"{'nivel':>5} {'arma':7} {'fuga px/s':>9} {'sprint':>6}  resultado        t(s) golpes fugiu(tiles) Stamina minima")
    for L in (10, 20, 30):
        for arma in ("Bastao", "Soco"):
            for vf in (75, 60):
                for sp in (True, False):
                    ok, t, h, fl, sm = run(vf, 140 * m_tor(L), arma, sprint=sp)
                    print(f"{L:>5} {arma:7} {vf:>9} {'sim' if sp else 'nao':>6}  {'nocauteou' if ok else 'NAO nocauteou':14} {t:6.1f} {h:6} {fl:8.1f} {sm:12.0f}")
def tri():
    print("Triceratops (Semi-agressivo): provocado investe; ataque 20 base x (1+0,04(L-10)) a cada 2,5 s, 1o ataque 0,5 s depois do 1o golpe [premissa]; Bastao; dano minimo 1 e reducao da armadura")
    for L in (24, 28, 32, 36, 40):
        mx = 160 * m_tor(L); dmg = 20 * (1 + 0.04 * (L - 10))
        hit, cd, _ = ARMAS["Bastao"]
        tor = 0.0; n = 0
        while tor < mx: n += 1; tor += hit - (DECAY * cd if tor + hit < mx else 0)
        tfim = (n - 1) * cd; ataques = 0 if tfim < 0.5 else 1 + int((tfim - 0.5) / 2.5)
        out = []
        for nome, red in (("sem armadura", 0.0), ("couro 25%", .25), ("metal 40%", .40)):
            tot = ataques * max(1.0, dmg * (1 - red)); out.append(f"{nome} {tot:5.1f}")
        print(f"  L{L:<3} torpor {mx:4.0f}: {n:2} golpes, {tfim:4.1f} s, {ataques} ataques de {dmg:4.1f} | " + " | ".join(out) + "  (vida 100)")
{"para": para, "tri": tri}[sys.argv[1]]()
