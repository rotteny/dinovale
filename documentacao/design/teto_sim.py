#!/usr/bin/env python3
"""Tetos de nivel (Dino Vale): spawn, evolucao do dino, servidor e jogador. Biblioteca padrao.
Uso: python3 teto_sim.py spawn|teto|xp|saber"""
import sys, math
from nivel_sim import final_level
BANDA = {"Dodo": (3, 10), "Paquicefalo": (5, 20), "Utahraptor": (10, 25), "Parassaurolofo": (10, 30), "Triceratops (v0.2)": (18, 24), "Triceratops (1.0)": (18, 40)}
EXP = 2.0           # poucos altos: nivel = min + floor((max-min+1) x u^2)
def spawn():
    print("faixa de spawn por especie; distribuicao com poucos altos: nivel = min + floor((max-min+1) x u^2), u uniforme")
    for sp, (a, b) in BANDA.items():
        n = b - a + 1; pm = [(math.floor(n * u ** EXP)) for u in [(i + .5) / 10000 for i in range(10000)]]
        mean = a + sum(pm) / len(pm); alto = sum(1 for x in pm if x >= 0.75 * n) / len(pm); topo = sum(1 for x in pm if x == n - 1) / len(pm)
        unif = a + (n - 1) / 2
        print(f"  {sp:20} L{a}-{b}: media {mean:4.1f} (uniforme {unif:4.1f}), no quarto de cima {alto*100:4.1f}% (uniforme 25%), no nivel maximo {topo*100:4.1f}%")
def teto():
    print("teto de evolucao do dino: 2x o nivel de doma. Tres leituras; servidor vence (dino_nivel_max)")
    print("  exemplo do dono: selvagem 100, bonus de Eficiencia 50 (final 150):")
    print("    A) 2x selvagem = 200 | B) 2x final = 300 | C) 2x selvagem + bonus = 250")
    print(f"{'caso':26}{'selv':>5}{'E':>5}{'final':>6}{'A':>5}{'B':>5}{'C':>5}   subida possivel (A/B/C)")
    for nome, L, E in (("Paq tutorial, Baga", 8, 27), ("Paq, Racao A", 10, 91), ("Utahraptor, B", 15, 81), ("Parassaurolofo, A", 20, 91), ("Triceratops, A", 24, 59), ("Triceratops L28, A", 28, 59)):
        f = final_level(L, E); A = 2 * L; B = 2 * f; C = 2 * L + (f - L)
        print(f"  {nome:24}{L:>5}{E:>5}{f:>6}{A:>5}{B:>5}{C:>5}   {A-f}/{B-f}/{C-f}")
    print("  Em A o teto nao depende de E: Eficiencia so adianta niveis (poupa XP), nao eleva o fim. Em B e C eleva.")
    for cap in (75, 180): print(f"  servidor {cap}: dino selvagem 100 com teto 200 vira min(200,{cap}) = {min(200,cap)}")
def xp():
    print("XP do dino domado: niveis extras g custam 20+10g (companhia, 15 XP/min); tempo ate o teto de cada leitura")
    def custo(n): return sum(20 + 10 * g for g in range(1, n + 1))
    for nome, L, E in (("Paquicefalo L10, A", 10, 91), ("Triceratops L24, A", 24, 59)):
        f = final_level(L, E)
        for lab, cap in (("A", 2 * L), ("B", 2 * f), ("servidor 75", 75)):
            n = max(0, min(cap, 75) - f)
            print(f"  {nome:20} final {f}: teto {lab:11} {cap:3} (efetivo {min(cap,75)}), {n:2} niveis = {custo(n):6} XP = {custo(n)/15/60:5.1f} h")
    def xpj(L): return sum(30 + 15 * (i - 1) for i in range(1, L))
    print("XP do jogador: ate L20 %d (%.1f h a 13/min); L68 %d (%.0f h); L75 %d (%.0f h)" % (xpj(20), xpj(20)/13/60, xpj(68), xpj(68)/13/60, xpj(75), xpj(75)/13/60))
def saber():
    def s(L): return (L - 1) + (1 if L >= 3 else 0) + L // 5
    print("Saber por teto do jogador: custo v0.2 = 22, 1.0 = 81")
    for cap in (20, 30, 50, 68, 75, 100): print(f"  jogador_nivel_max {cap:3}: Saber {s(cap):3} | v0.2 {'cobre' if s(cap)>=22 else 'NAO cobre'} | 1.0 {min(100, 100*s(cap)/81):4.0f}% | pontos de atributo {cap-1}")
    print("  primeiro nivel que completa a 1.0:", next(L for L in range(1, 200) if s(L) >= 81))
{"spawn": spawn, "teto": teto, "xp": xp, "saber": saber}[sys.argv[1]]()
