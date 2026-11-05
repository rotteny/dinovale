#!/usr/bin/env python3
"""Armas, torpor continuo, fruta e preparado de sono (Dino Vale). Biblioteca padrao.
Uso: python3 armas_sim.py ko|dardo|fuga|dormindo|jogador|custo   [premissa] = valor a testar jogando."""
import sys, math
DEC_AWAKE, DEC_SLEEP = 5.0, 1.0           # reais, TorporComponent.gd
CAP = 3                                    # doses simultaneas (compartilhado entre dardo, flecha, fruta, preparado)
ARMAS = {  # nome: (dano, torpor imediato, taxa/s, duracao s, cooldown s)
 "Soco": (1, 10, 0, 0, 0.6), "Bastao-de-sono": (2, 30, 0, 0, 0.7),
 "Dardo de sono": (0, 10, 8, 5, 1.0), "Flecha de sono (M4)": (1, 15, 12, 5, 1.2)}
ITENS = {  # preparado so e dado ao dino; na tabela do jogador ele aparece so como contraprova
 "Fruta-do-sono": (6, 5), "Preparado de sono": (12, 5)}   # taxa/s, duracao s (so pela boca)
ESP = {"Paquicefalo L12": 104, "Utahraptor L20": 144, "Parassaurolofo L20": 168, "Triceratops L28": 218}

def simula(T, doses, dec, tmax=60.0, dt=0.05, imm=0.0, fire_every=1.0, fuga=None):
    """doses: lista (taxa, dur). Dispara a cada fire_every (cap CAP, a 4a renova a mais antiga). Retorna tempo ate torpor>=T."""
    tor, t, act, nxt = 0.0, 0.0, [], 0.0
    while t < tmax:
        if t >= nxt:
            rate, dur = doses
            if len(act) >= CAP: act.remove(min(act, key=lambda a: a[1]))
            act.append([rate, dur]); tor += imm; nxt += fire_every
        flow = sum(a[0] for a in act) - dec
        tor = max(0.0, tor + flow * dt)
        for a in act: a[1] -= dt
        act = [a for a in act if a[1] > 0]
        t += dt
        if tor >= T: return t, tor
    return None, tor

def ko():
    print("Corpo a corpo: golpes ate nocautear com queda acordada de 5/s (torpor liquido = n*golpe - 5*cd*(n-1))")
    for sp, T in ESP.items():
        print(f" {sp} (torpor {T}):")
        for nome in ("Soco", "Bastao-de-sono"):
            d, ti, _, _, cd = ARMAS[nome]
            for pts in (0, 10):
                g = ti * (1 + 0.06 * pts); n = 1
                while g * n - DEC_AWAKE * cd * (n - 1) < T: n += 1
                print(f"   {nome:15} Dano {pts:2} pts: golpe {g:5.1f} -> {n:2} golpes, {(n-1)*cd:5.1f} s, dano causado {n*d*(1+0.06*pts):5.1f}")
def dardo():
    print("Dardo (imm 10 + 8/s x 5 s = 50 por dose), 1 a cada 1,0 s, cap 3, dino ACORDADO (queda 5/s)")
    for sp, T in ESP.items():
        t, tor = simula(T, (8, 5), DEC_AWAKE, imm=10)
        print(f"   {sp:20} nocaute em {t if t is None else round(t,1)} s")
    print("Flecha de sono (imm 15 + 12/s x 5 s = 75), cd 1,2 s, cap 3")
    for sp, T in ESP.items():
        t, tor = simula(T, (12, 5), DEC_AWAKE, imm=15, fire_every=1.2)
        print(f"   {sp:20} nocaute em {t if t is None else round(t,1)} s")
    print("Uma dose sozinha em dino acordado: liquido = 10 + (8-5)*5 = %d de 50 (decai a maior parte)" % (10 + 3 * 5))
def fuga():
    print("Medroso fugindo (Parassaurolofo L20, torpor 168, vel 75 px/s; faixas 50%%: x0,85 e 75%%: x0,65). Jogador anda 70, corre 120 por 4 s; alcance do dardo 96 px; partida a 80 px")
    T, dt = 168, 0.05
    for cd in (1.0,):
        tor, t, act, nxt, dist, sp_run, flee_end = 0.0, 0.0, [], 0.0, 80.0, 4.0, 15.0
        first = {}
        while t < flee_end:
            if dist <= 96 and t >= nxt:
                if len(act) >= CAP: act.remove(min(act, key=lambda a: a[1]))
                act.append([8, 5]); tor += 10; nxt = t + cd
            tor = max(0, tor + (sum(a[0] for a in act) - DEC_AWAKE) * dt)
            for a in act: a[1] -= dt
            act = [a for a in act if a[1] > 0]
            band = 3 if tor >= .75 * T else 2 if tor >= .5 * T else 1 if tor >= .25 * T else 0
            vf = 75 * (0.65 if band == 3 else 0.85 if band == 2 else 1.0)
            if tor >= T: print(f"   nocaute em {t:.1f} s, distancia {dist:.0f} px"); break
            vp = 120 if sp_run > 0 else 70
            if sp_run > 0: sp_run -= dt
            dist += (vf - vp) * dt; t += dt
            if band >= 2 and 'b2' not in first: first['b2'] = (t, dist)
        else: print(f"   fuga acabou (15 s) com torpor {tor:.0f}/{T}, distancia {dist:.0f} px")
        if 'b2' in first: print(f"   faixa 2 (50%) em {first['b2'][0]:.1f} s, distancia {first['b2'][1]:.0f} px (jogador a 70 ja alcanca o x0,85 = 64 px/s)")
def dormindo():
    print("Dino DORMINDO (queda 1,0 a 1,5/s): fruta 6/s x 5 s = 30; preparado 12/s x 5 s = 60; dardo 50 (-2 E)")
    for q in (1.0, 1.5):
        print(f" manter o torpor parado por minuto: {60*q:.0f} a {q*60:.0f} torpor = {60*q/30:.1f} frutas ou {60*q/60:.1f} preparados ou {60*q/50:.1f} dardos")
    print("Tempo do jogador por item forcado: 1,5 s (acao); 2 frutas/min = 3 s/min de acao + 8 s de coleta")
def jogador():
    print("Jogador (torpor max 100, queda 5/s acordado). Come n itens com 0,5 s entre eles (cap 3 efeitos)")
    for nome, (rate, dur) in ITENS.items():
        for n in (1, 2, 3, 6, 9):
            tor, t, act, peak, nxt, left = 0.0, 0.0, [], 0.0, 0.0, n
            while t < 40 and tor < 100:
                if left and t >= nxt:
                    if len(act) >= CAP: act.remove(min(act, key=lambda a: a[1]))
                    act.append([rate, dur]); left -= 1; nxt = t + 0.5
                tor = max(0, tor + (sum(a[0] for a in act) - DEC_AWAKE) * 0.05)
                for a in act: a[1] -= 0.05
                act = [a for a in act if a[1] > 0]; peak = max(peak, tor); t += 0.05
            band = 'dorme' if tor >= 100 else 'faixa 3' if peak >= 75 else 'faixa 2' if peak >= 50 else 'faixa 1' if peak >= 25 else 'sem sinal'
            print(f"   {nome:18} x{n}: pico {peak:5.1f} -> {band}")
    print("Sono do jogador [premissa]: acorda em 30, queda dormindo 3/s: 70/3 = 23 s; dano recebido acorda; aliado acorda segurando a interacao 2 s")
def custo():
    fib, ped, nome_craft = 2.0, 2.5, 4.0   # s de coleta por unidade [premissa]
    dardo = (2 * fib + ped + nome_craft) / 3; fruta = 4.0
    print(f"Dardo: {dardo:.1f} s por dose de 50 = {dardo/50:.3f} s/torpor, mais 2 E. Valor de 1 E = 2 a 8 s (nivel_sim preco: 14 a 60 s/nivel, 0,14 nivel por E): dardo dormindo = {dardo+4:.1f} a {dardo+16:.1f} s -> {(dardo+4)/50:.2f} a {(dardo+16)/50:.2f} s/torpor")
    print(f"Fruta: 4 s por 30 = {fruta/30:.3f} s/torpor, 0 E. Preparado (3 frutas + 1 carne podre [4 s na carnica] + 4 s de bancada -> 3 de 60 = 180): {(3*fruta+4+4)/180:.3f} s/torpor")
    print("Conclusao: fruta e preparado custam menos que dardo em dormindo; dardo fica para dino acordado (alcance 6 tiles).")
    print("E por taxa de tempo continua: 0,3/s; 100 s de domar = -30 E; Baga Parassaurolofo L20: +4 E se trocar 2 dardos por frutas (nivel final +0,5)")
{"ko": ko, "dardo": dardo, "fuga": fuga, "dormindo": dormindo, "jogador": jogador, "custo": custo}[sys.argv[1]]()
