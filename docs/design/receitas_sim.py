#!/usr/bin/env python3
"""Arvore de receitas da 0.2 e ritmo de Saber (Dino Vale). Biblioteca padrao. Uso: python3 receitas_sim.py arvore|ritmo|ordem"""
import sys
# id: (nome, grupo, custo Saber, prereq, conhecida, marco)
CAT = {"A": "Armas", "R": "Armaduras", "M": "Mobilias", "C": "Construcoes", "D": "Recursos diversos"}
# id: (nome, categoria, tier, custo Saber, prereq, conhecida, marco)  | tier T1..T4; custo 0 = conhecida no inicio
R = {
 "bastao":   ("Bastao-de-sono", "A", 1, 0, [], True, "M1"),
 "machado":  ("Machado de pedra", "A", 1, 1, [], False, "M2"),
 "picareta": ("Picareta de pedra", "A", 1, 1, [], False, "M2"),
 "dardo":    ("Dardo de sono", "A", 2, 2, [], False, "M2"),
 "bastao_r": ("Bastao reforcado", "A", 2, 2, ["bastao"], False, "M2 cortavel"),
 "arco":     ("Arco", "A", 2, 2, [], False, "M4"),
 "flecha":   ("Flecha comum", "A", 2, 2, ["arco"], False, "M4"),
 "flecha_s": ("Flecha de sono", "A", 2, 2, ["arco"], False, "M4"),
 "boleadeira": ("Boleadeira", "A", 2, 2, [], False, "M4"),
 "lanca":    ("Lanca de pedra", "A", 3, 4, [], False, "M4"),
 "armadilha": ("Armadilha de laco", "A", 3, 4, ["corda"], False, "M4"),
 "machado_f": ("Machado de ferro", "A", 4, 6, ["machado", "barra_f"], False, "M6 (fora por agora)"),
 "picareta_f": ("Picareta de ferro", "A", 4, 6, ["picareta", "barra_f"], False, "M6 (fora por agora)"),
 "espada":   ("Espada", "A", 4, 6, ["barra_f"], False, "M6 (fora por agora)"),
 "besta":    ("Besta", "A", 4, 6, ["arco", "barra_f"], False, "M6 (fora por agora)"),
 "traje_pele": ("Traje de pele", "R", 1, 1, [], False, "M4"),
 "traje_couro": ("Traje de couro", "R", 2, 2, ["traje_pele", "couro_c"], False, "M4"),
 "escudo_m": ("Escudo de madeira", "R", 2, 2, [], False, "M4"),
 "traje_osso": ("Traje de osso e quitina", "R", 3, 4, ["traje_couro"], False, "M4+"),
 "traje_metal": ("Traje de metal", "R", 4, 6, ["traje_osso", "barra_f"], False, "M6 (fora por agora)"),
 "escudo_f": ("Escudo de metal", "R", 4, 6, ["escudo_m", "barra_f"], False, "M6 (fora por agora)"),
 "bancada":  ("Bancada comum", "M", 1, 0, [], True, "M2"),
 "bau":      ("Bau", "M", 1, 1, [], False, "M2"),
 "cama":     ("Cama de palha", "M", 1, 1, [], False, "M2 cortavel"),
 "placa":    ("Placa", "M", 1, 1, [], False, "M4 visual"),
 "cocho":    ("Cocho", "M", 2, 2, ["bau"], False, "M2 cortavel"),
 "canteiro": ("Canteiro", "M", 2, 2, [], False, "M4"),
 "tocha":    ("Tocha", "M", 2, 1, [], False, "M4 (com noite)"),
 "tapete":   ("Tapete de pele", "M", 2, 1, ["traje_pele"], False, "M4 visual"),
 "forja":    ("Forja", "M", 3, 4, ["tijolo"], False, "M6 (fora por agora)"),
 "composteira": ("Composteira", "M", 3, 4, ["canteiro"], False, "M4+"),
 "secador":  ("Secador", "M", 3, 4, [], False, "so se a carne apodrecer no inventario"),
 "fundacao": ("Fundacao de madeira", "C", 1, 0, [], True, "M2"),
 "parede":   ("Parede de madeira", "C", 1, 0, [], True, "M2"),
 "porta":    ("Porta de madeira", "C", 1, 0, [], True, "M2"),
 "curral":   ("Cerca e curral (madeira)", "C", 1, 2, ["parede"], False, "M2"),
 "palha_c":  ("Parede, cerca e porta de palha", "C", 1, 1, [], False, "M4"),
 "portao":   ("Portao de dino", "C", 2, 1, ["curral"], False, "M2"),
 "teto":     ("Teto", "C", 2, 2, ["parede"], False, "M4"),
 "rampa":    ("Rampa e escada", "C", 2, 2, ["fundacao"], False, "M4"),
 "pedra_c":  ("Fundacao e parede de pedra", "C", 3, 4, ["tijolo"], False, "M4+"),
 "portao_r": ("Portao reforcado", "C", 3, 4, ["portao", "pedra_c"], False, "M4+"),
 "muralha":  ("Muralha", "C", 4, 6, ["pedra_c", "argamassa"], False, "M6 (fora por agora)"),
 "racao_c":  ("Racao C", "D", 1, 0, [], True, "M2"),
 "bandagem": ("Bandagem", "D", 1, 1, [], False, "M2"),
 "corda":    ("Corda", "D", 1, 1, [], False, "M4"),
 "racao_b":  ("Racao B", "D", 2, 2, ["racao_c"], False, "M2"),
 "racao_a":  ("Racao A", "D", 2, 3, ["racao_b"], False, "M2"),
 "preparado": ("Preparado de sono", "D", 2, 3, ["dardo"], False, "M2 cortavel"),
 "couro_c":  ("Couro curtido", "D", 2, 2, [], False, "M4"),
 "tecido":   ("Tecido", "D", 2, 2, ["corda"], False, "M4"),
 "tijolo":   ("Tijolo", "D", 2, 2, [], False, "M4"),
 "argamassa": ("Argamassa (cal e areia)", "D", 3, 4, ["tijolo"], False, "M6 (fora por agora)"),
 "barra_f":  ("Barra de ferro", "D", 3, 4, ["forja"], False, "M6 (fora por agora)"),
 "racao_s":  ("Racao S", "D", 3, 0, [], False, "M4, so por pergaminho"),
 "racao_sp": ("Racao S+", "D", 4, 0, [], False, "M4, so por pergaminho"),
 "aco":      ("Aco", "D", 4, 6, ["barra_f"], False, "M6 (fora por agora)"),
}
V02 = {k for k, v in R.items() if v[6].startswith(("M1", "M2"))}

def saber_ate(L): return sum(1 + (1 if n % 5 == 0 else 0) for n in range(2, L + 1))
def xp_ate(L): return sum(30 + 15 * (i - 1) for i in range(1, L))
def nivel_em(minutos, rate):
    L = 1
    while L < 20 and xp_ate(L + 1) <= minutos * rate: L += 1
    return L
def arvore():
    n02 = [k for k in V02]; tot = sum(R[k][3] for k in n02)
    print(f"v0.2: {len(n02)} receitas, {sum(1 for k in n02 if R[k][5])} conhecidas, custo total {tot} Saber (Saber ate L20: {saber_ate(20)})")
    for c, nome in CAT.items():
        print(f" {nome}: 1.0 = {sum(1 for v in R.values() if v[1]==c)} receitas, custo {sum(v[3] for v in R.values() if v[1]==c)}; v0.2 = {sum(1 for k in n02 if R[k][1]==c)}")
    for k, v in R.items():
        assert all(p in R for p in v[4]), k
    print("total 1.0:", len(R), "receitas, custo", sum(v[3] for v in R.values()), "Saber")
    for L in (20, 50, 75): print(f"  Saber ate L{L}: {saber_ate(L)}")
    def d(k): return 0 if not R[k][4] else 1 + max(d(p) for p in R[k][4])
    print("cadeia mais longa:", max(d(k) for k in R), "(1.0) |", max(d(k) for k in V02), "(0.2)")
def ritmo():
    print("Saber acumulado: 1 por nivel (L2 a L20), +1 nos niveis 5, 10, 15, 20")
    for L in (3, 5, 8, 10, 12, 15, 20):
        print(f"  L{L:2}: {saber_ate(L):2} Saber | " + "  ".join(f"{r} XP/min: {xp_ate(L)/r:5.0f} min" for r in (8, 13, 20)))
    print("Pool unico (atributo + receita): 19 + 22 = 41 contra 19 disponiveis: nao fecha. Pools separados: 19 e 23.")
def ordem():
    ordem_ = ["dardo", "racao_b", "curral", "machado", "picareta", "bau", "bandagem", "portao", "cama", "racao_a", "cocho", "preparado", "bastao_r"]
    acc = 0
    print("Ordem recomendada (13 XP/min): custo acumulado, nivel em que fecha, minutos")
    for k in ordem_:
        acc += R[k][3]; L = 2
        while L < 20 and saber_ate(L) < acc: L += 1
        print(f"  {R[k][0]:20} +{R[k][3]} = {acc:2} Saber -> nivel {L:2}, {xp_ate(L)/13:4.0f} min")
def armadura():
    print("Traje (1 slot, sem durabilidade): reducao e peso [premissa]; luta contra Triceratops L42 (torpor 262, mordida 45,6 / 2,5 s), Bastao 30 (ou 48 com 10 pts de Dano), vida 100")
    tr = {"sem traje": (0, 0), "T1 pele": (10, 2), "T2 couro": (20, 5), "T3 osso": (30, 9), "T4 metal": (40, 14)}
    for dano, hit in (("sem pontos", 30), ("10 pts Dano", 48)):
        n = 1
        while hit * n - 3.5 * (n - 1) < 262: n += 1
        t = (n - 1) * 0.7; bites = int(t // 2.5)
        print(f" {dano}: {n} golpes, {t:.1f} s, {bites} mordidas")
        for nome, (red, kg) in tr.items():
            dmg = bites * 45.6 * (1 - red / 100)
            print(f"    {nome:10} -{red:2}%  dano levado {dmg:5.1f}  peso {kg:2} kg = {100*kg/50:3.0f}% dos 50 kg")
    print("Em L12 a L28 (0.2): Utahraptor L20 mordida 11,2; Triceratops L28 mordida 34,4: 1 mordida por luta; T1 poupa 1 a 3 de vida: nao justifica.")
{"arvore": arvore, "ritmo": ritmo, "ordem": ordem, "armadura": armadura}[sys.argv[1]]()
