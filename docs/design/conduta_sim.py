#!/usr/bin/env python3
"""Perseguição 1D: jogador contra dino que foge. Python puro. python3 conduta_sim.py"""
WALK, SPRINT, STAM, DRAIN, REGEN, RESUME = 70.0, 120.0, 100.0, 25.0, 15.0, 20.0
REACH, HIT, CD, DECAY, TMAX = 24.0, 30.0, 0.7, 5.0, 100.0
def band_mult(f, on):
    if not on: return 1.0
    return 1.0 if f < .5 else (0.85 if f < .75 else 0.65)
def run(vf, gap0, hesit, slow=True, sprint=True, tmax=100.0, pause=True):
    dt = .01; t = 0; gap = gap0; tor = 0.0; stam = STAM; blocked = False; cd = 0; hits = 0; first = None
    while t < 25:
        t += dt; cd = max(0, cd - dt); tor = max(0, tor - DECAY * dt)
        f = tor / tmax
        started = first is not None
        vd = 0.0 if (started and t - first < hesit) or (first is None and False) else vf * band_mult(f, slow)
        if pause and f >= .75 and int(t / 0.8) % 5 == 4: vd = 0.0   # pausa ~0,8 s a cada 4 s
        if first is None and gap0 > 100: vd = vf   # covarde já corre ao ver
        vp = SPRINT if (sprint and not blocked and stam > 0) else WALK
        if vp == SPRINT: stam -= DRAIN * dt
        else: stam = min(STAM, stam + REGEN * dt)
        if stam <= 0: blocked = True
        if blocked and stam >= RESUME: blocked = False
        gap = max(0.0, gap + (vd - vp) * dt)
        if gap <= REACH and cd == 0:
            tor += HIT; hits += 1; cd = CD
            if first is None: first = t
            if tor >= tmax: return True, t, hits
    return False, t, hits
cases = [("Covarde, Gallimimus (1o golpe de perto, susto 0,8 s, foge a 85; fuga própria da espécie)", 85, 20, 0.8, 100.0),
         ("Medroso (FUTURO, sem marco): vê a 8 tiles e foge a 85", 85, 128, 0.0, 100.0),
         ("Covarde, Parassaurolofo (torpor 140; 1o golpe de perto, foge a 75 após susto 0,8 s)", 75, 20, 0.8, 140.0),
         ("Covarde, torpor 100 (referência anterior)", 75, 20, 0.8, 100.0),
         ("Curioso, Oviraptor (a 3 tiles, foge a 75 após 0,5 s)", 75, 48, 0.5, 100.0)]
for name, vf, g0, h, tm in cases:
    print(name)
    for label, kw in (("com faixas de torpor + sprint", {}), ("sem lentidão de torpor", dict(slow=False, pause=False)), ("com faixas, sem sprint", dict(sprint=False))):
        ok, t, hits = run(vf, g0, h, tmax=tm, **kw)
        print(f"   {label:32} -> {'nocauteou' if ok else 'NAO nocauteou':14} t={t:5.1f}s golpes={hits}")

# Dodo (Covarde de grupo, domavel: torpor 50, ver covarde_sim.py dodo; aqui a caca: vida 24): Lança dano 12, recarga 0,9 s, alcance 1,8 tiles; susto 0,8 s, fuga 75 px/s; grupo foge a 8 tiles com atraso 0,5 s
print("Covarde, Dodo caçado (Lança: 2 golpes de 12 matam 24 de vida; para domar, Bastão: covarde_sim.py dodo)")
for g in (10, 20, 28):
    gap2 = g + 75 * (0.9 - 0.8) - 0.0     # o jogador também anda para ele na recarga; pior caso: parado
    print(f"   1o golpe a {g} px (alcance 28,8): 2o golpe em 0,9 s, dino fugiu {75*(0.9-0.8):.1f} px -> {'acerta' if gap2 <= 28.8 else 'jogador dá 1 passo (70 px/s x 0,1 s = 7 px)'} -> morre (o dino so comeca a andar em 0,8 s e o 2o golpe cai em 0,9 s)")
print("   vizinhos do grupo a <= 8 tiles fogem 0,5 s depois do 1o golpe: 1 morte por visita ao grupo; reencontro estimado 8 s [premissa]")
