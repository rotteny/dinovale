#!/usr/bin/env python3
"""Durabilidade, validade, Lanca, Dodo/Listro e primeira hora (Dino Vale). Biblioteca padrao.
Uso: python3 durab_sim.py lanca|ferr|reparo|hora|oferta|validade"""
import sys, math
# ---- Lanca de madeira [premissa]
L = dict(dano=12, torpor=0, cd=0.9, stam=5, alcance=1.8, graveto=2, madeira=3, durab=80)
# presas: vida, carne base, couro base
PRESA = {"Dodo": (24, 2, 1), "Listro": (36, 3, 2)}
UTA_VIDA20 = 126      # 7 golpes de 18 do desenho antigo
def lanca():
    for n, (v, c, k) in PRESA.items():
        h = math.ceil(v / L["dano"]); print(f"{n}: vida {v} -> {h} golpes, {h*L['cd']:.1f} s, stamina {h*L['stam']}, durab {h+1}")
    h = math.ceil(UTA_VIDA20 / L["dano"]); print(f"Utahraptor L20 (vida {UTA_VIDA20}): {h} golpes, {h*L['cd']:.1f} s, mordidas ~{h*L['cd']/2:.0f} (7,5 dps), stamina {h*L['stam']}, durab {h}")
    print("antiga Lanca 18: 7 golpes, 5,4 s | Soco: 126 golpes (invalido)")
# ---- Ferramentas
BASE = {"madeira": 3/8, "pedra": 4/10}   # un/s com maos [premissa GDD 7]
FERR = {  # nome: (mult rendimento, durab em s de coleta ou golpes)
 "Machado de pedra": (2.0, 150), "Picareta de pedra": (2.0, 120),
 "Machado de ferro": (3.5, 300), "Picareta de ferro": (3.5, 300)}
def ferr():
    for n, (m, d) in FERR.items():
        b = BASE["madeira"] if "Machado" in n else BASE["pedra"]
        print(f"{n}: {b*m:.2f} un/s, {d} s de uso = {b*m*d:.0f} unidades por durabilidade cheia")
    print(f"maos: madeira {BASE['madeira']:.3f} un/s, pedra {BASE['pedra']:.2f} un/s")
    print("ferro/pedra: 1,75x por segundo, 2x a 2,5x vida util = 3,5x a 4,4x unidades por ferramenta")
    print("abrigo 32 madeira: machado de pedra", round(32/(BASE['madeira']*2)), "s =", round(32/(BASE['madeira']*2)), "durab (de 100)")
def reparo():
    print("Reparo = ceil(50% do custo de material x fracao que falta), na Bancada, 1 s por 10% [premissa]")
    for n, mat, dur in (("Lanca", {"graveto": 2, "madeira": 3}, 80), ("Machado pedra", {"madeira": 3, "pedra": 2, "fibra": 1}, 100), ("Picareta pedra", {"madeira": 3, "pedra": 3, "fibra": 1}, 100)):
        for falta in (0.5, 1.0):
            c = {k: math.ceil(v * 0.5 * falta) for k, v in mat.items()}
            print(f"  {n} {int(falta*100)}% gasto: {c}, {10*falta:.0f} s")
def hora():
    print("PRIMEIRA HORA, consumo de durabilidade (13 XP/min depois do L3; 10 antes)")
    dodos = 20; hits = 2; lanca_use = dodos*(hits+1) + 11   # + 1 luta com Utahraptor
    print(f"  Lanca: {dodos} Dodos x 3 + 11 golpes no Utahraptor = {lanca_use} de 80 -> {lanca_use/80:.1f} reparos")
    mad = 32 + 24 + 30; ped = 4 + 36
    tm = mad/(BASE['madeira']*2); tp = ped/(BASE['pedra']*2)
    print(f"  Machado: {mad} madeira (abrigo, curral, bau, bancada) = {tm:.0f} s de 150 -> {tm/150:.1f} reparos")
    print(f"  Picareta: {ped} pedra = {tp:.0f} s de 120 -> {tp/120:.1f} reparos")
    rep = lanca_use/80 + tm/150 + tp/120
    print(f"  ~{rep:.1f} reparos x 10 s = {rep*10:.0f} s de 3600 ({rep*10/36:.1f}%), custo ~{rep*3:.0f} madeira/pedra: ruido, nao punicao")
    print("  Bastao-de-sono 120 golpes: KO de Paq 4 golpes -> 30 KOs; Soco nao gasta")
def oferta():
    print("OFERTA DE CARNE (Lanca + Dodo/Listro) x DEMANDA")
    tempo = {"Dodo": 12+8+2*0.9+ 2*1.5+3 + 10,   # +8 s: o grupo foge (Covarde) e o jogador reencontra outro [premissa]
              "Listro": 15+3*0.9+3*1.5+2*3+10}
    for n, (v, c, k) in PRESA.items():
        lvl = 8 if n == "Dodo" else 12
        y = max(1, round(c*max(0.7, 1+0.03*(lvl-10)))); yk = max(1, round(k*max(0.7, 1+0.03*(lvl-10))))
        print(f"  {n} L{lvl}: {y} carne + {yk} couro, ciclo ~{tempo[n]:.0f} s (alcancar+matar+coletar+voltar) = {y*3600/tempo[n]:.0f} carne/h de esforco continuo")
    dem = {"Utah L15 (Rubra A ou B)": 10, "Utah L15 (Rubra C)": 21, "Utah manada 14,4/h x 5": 72}
    for k, v in dem.items(): print(f"  demanda {k}: {v} carne = {v/2:.0f} Dodos ({v/2*37/60:.1f} min) ou {v/3:.0f} Listros")
    print("  spawn Dodo 12/zona + Listro 8, respawn 10 min: teto 72 + 48 = 120 animais/h = 240+144 carne/h")
    print("  carne podre: carcaca nao coletada vira carniça (10-20 min) ceil(carne/4): Dodo 1, Listro 1, Paq 1, Utah 2")
    print("  carne podre por validade: pilha vencida ceil(n/4). Demanda: 1 podre por 3 preparados (M2 cortavel) ~ 2 por domesticacao")
    print("  oferta de podre numa hora de caça ~10 carcaças largadas = 10 podre; demanda 2-6: sobra 2x a 5x")
def validade():
    print("VALIDADE (minutos reais; tempo corre com o servidor ligado) [premissa]")
    for n, m in (("Carne crua", 30), ("Carne assada (Fogueira)", 90), ("Baga", 45), ("Cochilo", 30), ("Preparado de sono", 45), ("Carne podre", None), ("Racao C/B/A", None)):
        print(f"  {n:26} {m if m else 'nao vence'}")
    print("  aviso a 25% do prazo: crua 7,5 min; assada 22,5 min; Cochilo 7,5 min")
    print("  domesticacao: carne para Utah (10 a 21) e colhida e usada em ~5 a 10 min [premissa]; margem 30/10 = 3x")
    print("  tolerancia de juncao 2 min: perde no maximo 2 de 30 min (6,7%) da validade da pilha fresca")
{"lanca": lanca, "ferr": ferr, "reparo": reparo, "hora": hora, "oferta": oferta, "validade": validade}[sys.argv[1]]()
