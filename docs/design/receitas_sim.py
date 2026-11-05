#!/usr/bin/env python3
"""Arvore de receitas ativa (Dino Vale, enxuta em 06/11). Biblioteca padrao. Uso: python3 receitas_sim.py arvore|ritmo|ordem|cortes"""
import sys
CAT = {"A": "Armas e ferramentas", "R": "Armaduras", "M": "Mobilias", "C": "Construcoes", "D": "Recursos diversos"}
# id: (nome, cat, tier, Saber, prereq, conhecida, marco, receitas no no)
R = {  # id: (nome, cat, tier, Saber, prereq (lista plana: vazio), conhecida, marco, receitas no no, estacao)
 "lanca":    ("Lanca de madeira", "A", 1, 0, [], True, "M1 (item) / M2", 1, "Maos"),
 "machado":  ("Machado de pedra", "A", 1, 0, [], True, "M2", 1, "Maos"),
 "picareta": ("Picareta de pedra", "A", 1, 0, [], True, "M2", 1, "Maos"),
 "fogueira": ("Fogueira (e carne assada)", "M", 1, 0, [], True, "M2", 1, "Maos"),
 "bancada":  ("Bancada comum", "M", 1, 1, [], False, "M2", 1, "Maos"),
 "bastao":   ("Bastao-de-sono (nasce no inventario no M1)", "A", 1, 1, [], False, "M2", 1, "Maos"),
 "pilao":    ("Pilao (item portatil)", "A", 1, 1, [], False, "M2 cortavel", 1, "Maos"),
 "racao_c":  ("Racao C", "D", 1, 1, [], False, "M2", 1, "Bancada"),
 "racao_b":  ("Racao B", "D", 2, 2, [], False, "M2", 1, "Bancada"),
 "racao_a":  ("Racao A", "D", 2, 3, [], False, "M2", 1, "Bancada"),
 "abrigo":   ("Abrigo de madeira (fundacao, parede, porta)", "C", 1, 1, [], False, "M2", 3, "Maos"),
 "curral":   ("Cerca e curral (madeira)", "C", 2, 2, [], False, "M2", 1, "Maos"),
 "portao":   ("Portao de dino", "C", 2, 1, [], False, "M2", 1, "Maos"),
 "bau":      ("Bau", "M", 1, 1, [], False, "M2", 1, "Maos"),
 "cocho":    ("Cocho", "M", 2, 2, [], False, "M2", 1, "Maos"),
 "bandagem": ("Bandagem", "D", 1, 1, [], False, "M2", 1, "Maos"),
 "preparado": ("Preparado de sono (no Pilao)", "D", 2, 3, [], False, "M2 cortavel", 1, "Pilao"),
 # ---- 1.0 (depois da 0.2)
 "corda":    ("Corda", "D", 1, 1, [], False, "M4", 1, "Maos"),
 "arco":     ("Arco", "A", 2, 2, [], False, "M4", 1, "Maos"),
 "flecha":   ("Flecha comum", "A", 2, 2, [], False, "M4", 1, "Maos"),
 "flecha_s": ("Flecha de sono", "A", 2, 2, [], False, "M4", 1, "Maos"),
 "boleadeira": ("Boleadeira", "A", 2, 2, [], False, "M4", 1, "Maos"),
 "traje_couro": ("Conjunto de couro (5 pecas)", "R", 2, 2, [], False, "M4", 5, "Maos"),
 "traje_fibra": ("Conjunto de fibra (5 pecas)", "R", 1, 1, [], False, "depois do playtest", 5, "Maos"),
 "canteiro": ("Canteiro", "M", 2, 2, [], False, "M4", 1, "Maos"),
 "palha_c":  ("Palha (parede, cerca, porta)", "C", 1, 1, [], False, "M4", 3, "Maos"),
 "tijolo":   ("Tijolo", "D", 2, 2, [], False, "M4+", 1, "Maos"),
 "pedra_c":  ("Pedra (fundacao e parede)", "C", 3, 4, [], False, "M4+", 2, "Maos"),
 "racao_s":  ("Racao S", "D", 3, 0, [], False, "M4, so pergaminho", 1, "Bancada"),
 "racao_sp": ("Racao S+", "D", 4, 0, [], False, "M4, so pergaminho", 1, "Bancada"),
 "forja":    ("Forja", "M", 3, 4, [], False, "M4 a M5", 1, "Bancada"),
 "espada":   ("Espada de ferro", "A", 4, 6, [], False, "M4 a M5", 1, "Bancada"),
 "machado_f": ("Machado de ferro", "A", 4, 6, [], False, "M5", 1, "Bancada"),
 "picareta_f": ("Picareta de ferro", "A", 4, 6, [], False, "M5", 1, "Bancada"),
 "traje_metal": ("Conjunto de metal (5 pecas)", "R", 4, 6, [], False, "M5", 5, "Bancada"),
 "mochila":  ("Mochila (item futuro, provisorio)", "M", 2, 2, [], False, "M4", 1, "Maos"),
 "sela_fibra": ("Sela de fibra", "A", 1, 1, [], False, "depois do playtest (montaria)", 1, "Maos"),
 "sela_couro": ("Sela de couro", "A", 2, 2, [], False, "depois do playtest (montaria)", 1, "Maos"),
 "sela_metal": ("Sela de metal", "A", 3, 4, [], False, "depois do playtest (montaria), M5", 1, "Bancada"),
 "besta":    ("Besta (usa as mesmas flechas)", "A", 3, 4, [], False, "M5", 1, "Bancada"),
}
V02 = {k for k, v in R.items() if v[6].startswith(("M1", "M2"))}
CORTADOS = ["Armadilha de lanca de laco", "Rifle, Dardo, Fosforo, Polvora, Silex (sem marco)", "Cama de fibra", "Bastao reforcado", "Traje de pele, de osso e de quitina", "Escudo (todos)", "Couro curtido", "Placa", "Tapete de pele", "Tocha", "Secador", "Composteira", "Teto", "Rampa e escada", "Portao reforcado", "Muralha", "Tecido", "Argamassa", "Aco", "Bau reforcado", "Lanca de pedra", "estruturas de metal"]
def saber_ate(L): return (L - 1) + (1 if L >= 3 else 0) + L // 5     # 1 por nivel, +1 no 3 e +1 a cada multiplo de 5
def xp_ate(L): return sum(30 + 15 * (i - 1) for i in range(1, L))
def arvore():
    for nome, ks in (("v0.2", V02), ("1.0", set(R))):
        rec = sum(R[k][7] for k in ks); nos = len(ks); sab = sum(R[k][3] for k in ks); con = sum(R[k][7] for k in ks if R[k][5])
        print(f"{nome}: {rec} receitas em {nos} nos; {con} receitas conhecidas; custo {sab} Saber")
        for c, n in CAT.items():
            print(f"   {n:20} receitas {sum(R[k][7] for k in ks if R[k][1]==c):2}, Saber {sum(R[k][3] for k in ks if R[k][1]==c):2}")
    for L in (20, 50, 75): print(f"  Saber ate L{L}: {saber_ate(L)}")
    def d(k): return 0
    for k, v in R.items(): assert all(p in R for p in v[4]), k
    print("cadeia mais longa:", max(d(k) for k in R), "(1.0),", max(d(k) for k in V02), "(0.2)")
    print("metal (1.0): " + ", ".join(R[k][0] for k in ("forja", "machado_f", "picareta_f", "espada", "traje_metal", "besta")), "=", sum(R[k][3] for k in ("forja", "machado_f", "picareta_f", "espada", "traje_metal", "besta")), "Saber")
def por_peca():
    # alternativa rejeitada: 1 no de Saber por peca (custo por peca: fibra 1, couro 2, metal 4)
    extra = 5 * 1 + 5 * 2 + 5 * 4 - (1 + 2 + 6)
    tot = sum(v[3] for v in R.values()) + extra
    L = next(l for l in range(1, 200) if saber_ate(l) >= tot)
    print(f"Saber por peca: 1.0 = {tot} Saber (+{extra}); completa no L{L} (teto do jogador 75 = {saber_ate(75)})")
def estacoes():
    for nome, ks in (("v0.2", V02), ("1.0", set(R))):
        c = {}
        for k in ks: c[R[k][8]] = c.get(R[k][8], 0) + R[k][7]
        print(nome, "receitas por estacao:", c)
def ritmo():
    print("Saber: 1 por nivel (L2+), +1 no nivel 3, +1 a cada multiplo de 5")
    for L in (2, 3, 4, 5, 6, 8, 10, 12, 15, 20):
        print(f"  L{L:2}: {saber_ate(L):2} Saber | " + "  ".join(f"{r} XP/min: {xp_ate(L)/r:5.0f} min" for r in (8, 13, 20)))
def ordem():
    ordem_ = ["bancada", "bastao", "racao_c", "abrigo", "curral", "bandagem", "bau", "portao", "racao_b", "cocho", "racao_a", "pilao", "preparado"]
    acc = 0; print("Ordem recomendada (13 XP/min)")
    for k in ordem_:
        acc += R[k][3]; L = 2
        while L < 20 and saber_ate(L) < acc: L += 1
        print(f"  {R[k][0]:46} +{R[k][3]} = {acc:2} Saber -> L{L:2}, {xp_ate(L)/13:4.0f} min")
def cortes():
    print("Cortados da arvore ativa:", ", ".join(CORTADOS))
{"arvore": arvore, "ritmo": ritmo, "ordem": ordem, "cortes": cortes, "estacoes": estacoes, "por_peca": por_peca}[sys.argv[1]]()
