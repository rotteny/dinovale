#!/usr/bin/env python3
"""Fome do jogador, torpor por fome e armadura com dano minimo 1 (Dino Vale). Biblioteca padrao.
Uso: python3 fome_sim.py fome|ciclo|armadura"""
import sys, math
DECAY = 0.2; CRUA = 25; COZIDA = 35; BAGA = 10; PODRE = 5; PODRE_DANO = 6
REGEN = 0.5; LIMIAR = 70; COZ_REGEN = 1.0; COZ_S = 10
TORPOR_UP = 2.0; TORPOR_MAX = 100; FAINT_S = 8; WAKE_AT = 50; FAINT_DPS = 1.5; VIDA = 100
def fome():
    print(f"queda {DECAY}/s (codigo atual 0,5): 100 -> 0 em {100/DECAY:.0f} s ({100/DECAY/60:.1f} min); 100 -> 70 em {30/DECAY:.0f} s")
    for n, v in (("carne crua", CRUA), ("carne cozida", COZIDA), ("baga", BAGA), ("carne podre", PODRE)):
        print(f"  {n:13} +{v} = {v/DECAY:.0f} s de fome" + (f", -{PODRE_DANO} vida (nao mata)" if n == "carne podre" else ""))
    print(f"  cozida: +{COZ_REGEN*COZ_S:.0f} vida em {COZ_S} s | saciedade >{LIMIAR}: +{REGEN}/s (vida 100 em {VIDA/REGEN:.0f} s)")
    h = DECAY * 3600
    print(f"  consumo do jogador {h:.0f} fome/h = {h/CRUA:.0f} carne crua/h ou {h/COZIDA:.0f} cozida/h = {h/COZIDA/2:.0f} Dodos/h (~{h/COZIDA/2*30/60:.0f} min de caca)")
    print(f"  codigo atual 0,5/s: {0.5*3600/COZIDA:.0f} cozidas/h = {0.5*3600/COZIDA/2:.0f} Dodos/h (inviavel)")
def ciclo():
    sobe = (TORPOR_MAX - WAKE_AT) / TORPOR_UP
    ciclo = FAINT_S + sobe
    print(f"fome 0: torpor +{TORPOR_UP}/s liquido; faixas 25/50/75 em {25/TORPOR_UP:.1f}/{50/TORPOR_UP:.1f}/{75/TORPOR_UP:.1f} s; colapso em {TORPOR_MAX/TORPOR_UP:.0f} s")
    print(f"inconsciente {FAINT_S} s, dano {FAINT_DPS}/s = {FAINT_S*FAINT_DPS:.0f} por ciclo; acorda com torpor {WAKE_AT}; volta a 100 em {sobe:.0f} s; ciclo {ciclo:.0f} s")
    n = math.ceil(VIDA / (FAINT_S * FAINT_DPS))
    print(f"morte: {n} desmaios = {TORPOR_MAX/TORPOR_UP + (n-1)*ciclo + FAINT_S*VIDA/(FAINT_S*FAINT_DPS)%FAINT_S:.0f} s a partir do fome 0 (~{(TORPOR_MAX/TORPOR_UP + (n-1)*ciclo)/60:.1f} min); janelas para comer: {n-1} de {sobe:.0f} s")
    print(f"do fome 100 ao primeiro colapso: {100/DECAY + TORPOR_MAX/TORPOR_UP:.0f} s ({(100/DECAY + TORPOR_MAX/TORPOR_UP)/60:.1f} min); codigo atual: morte em {VIDA/(5/2):.0f} s")
def armadura():
    print("dano final = max(1, dano x (1 - min(0,5, reducao))), so para ataque com dano base >= 1; dano base 0 (dardo) continua 0")
    ataques = (("Soco-nivel / marimbondo (1)", 1), ("pancada 2", 2), ("Paq cabecada", 6.5), ("Utahraptor mordida", 11.25), ("Triceratops investida", 55))
    arm = (("sem", 0), ("fibra 10", .1), ("couro 25", .25), ("metal 40", .4), ("sem teto, 90", .9))
    print(f"{'ataque':30}" + "".join(f"{n[:18]:>20}" for n, _ in arm))
    for n, d in ataques: print(f"{n:30}" + "".join(f"{max(1, d*(1-min(.5, r)) if r < .9 else max(1, d*(1-r))):20.2f}" for _, r in arm))
    print("min 1 so muda o resultado para dano <= 1,7 com 40% (1,25 com 20%); sem teto, 90% daria 1 por golpe do Triceratops (5,5) e tornaria o jogador quase imune: o teto continua")
    for n, d in (("Traje de fibra", 100), ("Traje de couro", 150), ("Traje de metal", 300)): print(f"  {n}: {d} golpes sofridos; Utahraptor L20 (1 mordida/1,5 s) = {d*1.5/60:.1f} min de luta")
{"fome": fome, "ciclo": ciclo, "armadura": armadura}[sys.argv[1]]()
