#!/usr/bin/env python3
"""Rendimento de carcaca (Dino Vale). Biblioteca padrao. [premissa] = valor a testar jogando."""
BASE = {"Paquicefalo": (4, 1, 12), "Utahraptor": (5, 2, 20), "Parassaurolofo": (10, 3, 20), "Triceratops": (14, 5, 28)}  # carne, couro, nivel tipico
def f(L): return max(0.7, 1 + 0.03 * (L - 10))
T_CARNE, T_COURO = 1.5, 3.0     # s por unidade, sem ferramenta [premissa]
KG_CARNE, KG_COURO, FOME_CARNE = 0.5, 0.4, 25   # kg, kg, fome por carne [premissa; baga 10]
print("especie        nivel  carne couro  tempo   peso   fome(carnes)  carne podre (carcaca velha = ceil(carne/4))")
for sp, (c, k, L0) in BASE.items():
    for L in sorted({10, L0, 2 * L0 if sp != "Triceratops" else 42}):
        ca, ko = round(c * f(L)), round(k * f(L))
        t = ca * T_CARNE + ko * T_COURO; kg = ca * KG_CARNE + ko * KG_COURO
        print(f"{sp:15}{L:4} {ca:6} {ko:5} {t:6.1f}s {kg:6.1f}kg {ca*FOME_CARNE:5} ({ca*FOME_CARNE/0.1/60:4.0f} min de fome) {-(-ca//4):3}")
print("Peso do jogador 50 kg: Triceratops L28 = 22 carne + 8 couro = 14,2 kg (28%).")
print("Tempo no mundo [premissa]: fresca 10 min; carnica (so carne podre) ate 20 min; sacolinha 10 min; teto no mundo 8 carcacas e 20 sacolinhas.")
print("Save: 8 carcacas x ~40 B + 20 sacolinhas x ~(30 B + 4 B por item): menos de 2 KB.")
print("Fome: 1 carne = 25 = 250 s a 0,1/s; carcaca de Triceratops L28 = 550 fome = 92 min: abundancia, mas o jogador nao abate (Bastao dano 2) e a carcaca some em 10 min.")

# ---- fonte de carne sem Lanca (SHIKAMARU, 06/11) ----
import sys
if len(sys.argv) > 1 and sys.argv[1] == "carne":
    print("Demanda de carne [calculado a partir de racao.md 2.2 e da tabela do Utahraptor]")
    print("  Utahraptor L15 em Racao Rubra: C 13 refeicoes = 7 receitas x 3 Carne = 21; B 10 = 5 x 2 = 10 (+5 Tuberculo); A 9 = 5 x 2 = 10")
    print("  Rebanho: carne = 25 de fome [premissa]; a 0,1/s: 1 carne a cada 250 s = 14,4 por hora por Utahraptor domado")
    print("Oferta atual: kit inicial 4 carne; Bastao nao abate (40 golpes); Carnica so da carne podre -> furo")
    print("Opcao A (spawner de carcaca 'presa abatida', reusa a entidade de carcaca): 1 carcaca a cada 8 min por ponto, 4 carne + 1 couro (Paquicefalo L12)")
    for pts in (1, 2, 3):
        print(f"   {pts} ponto(s): {pts*4*60/8:4.0f} carne/h; 1 domesticacao (10 a 21) = {10/(pts*4*60/8)*60:4.1f} a {21/(pts*4*60/8)*60:4.1f} min de producao; 1 Utahraptor domado (14,4/h) = {14.4/(pts*30):.0%} da oferta")
    print("   carcaca que passa de 10 min vira carniça: 1 carne podre = 3 preparados -> o no de Carnica deixa de ser necessario")
    print("Opcao B (animal pequeno que morre com o Bastao): vida <= 10: 5 golpes, 3,5 s; mas e uma especie nova e Conduta Covarde so no M4")
    print("Opcao C (Lanca de volta): 18 de dano, Utahraptor L20 (112) = 7 golpes, 5,4 s, 3 mordidas = 34 de dano; contradiz a camada 1")
    print("Opcao D (no de Carne como Tuberculo): sem fantasia; nao cobre carne podre")
    print("Opcao E (abater o nocauteado): 4 s de acao por 4 carne; ciclo nocautear+abater+coletar ~15 s = 16 carne/min: carne trivial e mata a populacao selvagem")
