#!/usr/bin/env python3
"""Dano a estruturas (Dino Vale). Biblioteca padrao. [premissa] = valor a testar jogando.
Uso: python3 estruturas_sim.py tempo|curral|pedra"""
import sys, math
HP = {"palha": 1, "madeira": 3, "pedra": None}   # HP = 30 x unidades de madeira (palha: 10 por unidade)
PECAS = {  # peca: (unidades de material, multiplicador de vida)
 "cerca": 2, "parede": 2, "porta": 4, "portao": 4}
def vida(peca, mat):
    u = PECAS[peca]
    return None if mat == "pedra" else u * (10 if mat == "palha" else 30)
# dano estrutural por segundo: mordida / cooldown x fator [premissa]
ESP = {"Utahraptor L20 (Agressivo, fator 1,0)": (11.2, 1.5, 1.0), "Triceratops L28 (Semi-agressivo, so provocado, fator 2,0)": (34.4, 2.5, 2.0)}
BUILD_S = {"palha": 1.5, "madeira": 3.0, "pedra": 6.0}   # tempo de construcao por peca [premissa]
def tempo():
    print("Tempo para romper UMA peca (s)")
    for sp, (d, cd, k) in ESP.items():
        dps = d / cd * k
        print(f" {sp}: {dps:.1f} de dano/s")
        for mat in ("palha", "madeira", "pedra"):
            print("   " + f"{mat:8}" + "  ".join(f"{p} {('imune' if vida(p,mat) is None else f'{vida(p,mat)} HP = {math.ceil(vida(p,mat)/ (d*k)) * cd - cd if False else vida(p,mat)/dps:4.1f} s')}" for p in PECAS))
def curral():
    print("Curral 3x3 = 12 pecas de cerca. Atacante bate na peca mais proxima; o curral cede quando a primeira peca cai.")
    for mat, per_unit in (("palha", 2), ("madeira", 2), ("pedra", 3)):
        un = 12 * PECAS["cerca"] if mat != "pedra" else 12 * 3
        kg = un * {"palha": 0.05, "madeira": 0.5, "pedra": 1.5}[mat]
        print(f" {mat:8}: {un} unidades, {kg:5.1f} kg ({100*kg/50:3.0f}% do Peso 50), construcao {12*BUILD_S[mat]:5.1f} s")
    print("Janela util: aviso 3 s + nocaute do Utahraptor 3,5 s (Bastao, L20) = 6,5 s; com 10 pontos de Dano 2,1 s = 5,1 s. Domar dura 40 a 105 s.")
    d, cd, k = 11.2, 1.5, 1.0
    for mat in ("palha", "madeira"):
        for camadas in (1, 2):
            t = camadas * vida("cerca", mat) / (d / cd * k)
            print(f"   cerca de {mat}, {camadas} camada(s): {t:4.1f} s -> {'cobre a janela' if t >= 6.5 else 'NAO cobre'} ({'cobre' if t>=40 else 'nao cobre'} a domesticacao inteira)")
    print("Parede de madeira (%d HP): %.1f s; porta (%d): %.1f s" % (vida("parede","madeira"), vida("parede","madeira")/7.5, vida("porta","madeira"), vida("porta","madeira")/7.5))
def pedra():
    print("Pedra imune: protecao total, mas custa (parede de pedra = 4 Pedra, cerca de pedra = 3 Pedra = 4,5 kg, 6 s de construcao; curral 3x3 = 36 Pedra = 54 kg, 72 s)")
    print(" Mineracao: 10 s por 4 Pedra -> 36 Pedra = 90 s; carga do jogador 50 kg = 33 Pedra = 8 pecas por viagem (M4b: a zona livre de 70% leva 23 Pedra, 5 pecas; GDD 5.1b)")
    print(" Domar leva 40 a 105 s: construir 12 pecas de pedra (72 s) em volta do dormindo come a janela; madeira 36 s, palha 18 s")
    print(" Conclusao: a pedra e protecao de BASE (T3, 4 Saber, exige Tijolo); em campo, o decisor e palha (leve, fraca) x madeira (pesada, media)")
{"tempo": tempo, "curral": curral, "pedra": pedra}[sys.argv[1]]()
