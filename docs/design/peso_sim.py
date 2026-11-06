#!/usr/bin/env python3
"""Carga em faixas, Largar e bolsinha (Dino Vale, GDD 5.1b e 12.4; M4b, DEPOIS do MVP). Biblioteca padrao. [proposta] = valor a testar jogando.
Uso: python3 peso_sim.py curva|viagem|bolsinha|corpo|tudo"""
import sys, math
LIVRE, PARADA, VMIN = 0.70, 1.00, 0.40          # carga_livre, carga_parada, carga_vel_min [proposta, em dado]
WALK = 70.0                                      # px/s
def mult(c):
    if c >= PARADA: return 0.0
    if c <= LIVRE: return 1.0
    return 1.0 - (1.0 - VMIN) * (c - LIVRE) / (PARADA - LIVRE)
def curva():
    print("carga   mult   px/s   corre?   40 tiles (640 px)")
    for c in (0.5, 0.70, 0.75, 0.80, 0.85, 0.90, 0.95, 0.99, 1.0, 1.12):
        m = mult(c); t = f"{640/(WALK*m):5.1f} s" if m else "  parado"
        print(f"{c:5.0%}  {m:5.2f}  {WALK*m:5.1f}   {'sim' if c <= LIVRE else 'nao'}     {t}")
    print("degrau fixo alternativo (x0,6 de 70%% a 99%%): 40 tiles = %.1f s em toda a faixa; gradual custa 10,2 a 22,7 s" % (640/(WALK*0.6)))
def viagem():
    print("capacidade livre (70%%): jogador 50 kg = %.0f kg; Paquicéfalo L10 40 kg = %.0f kg; Parassaurolofo L20 130 kg = %.0f kg" % (35, 28, 91))
    for nome, kg in (("Abrigo minimo (32 madeira + 4 pedra + 1 fibra)", 38.05), ("2 abrigos", 76.1)):
        c = kg / 50; m = mult(c); print(f"  {nome}: {kg} kg = {c:.0%} do jogador -> mult {m:.2f}, 40 tiles: {(str(round(640/(WALK*m),1))+' s') if m else 'parado (2 viagens)'} (a pe livre: 9,1 s)")
    print("  2 abrigos com Paquicefalo L10: 76,1 kg em 90 kg de capacidade; dividido igual (38 kg cada) jogador 76% (x0,88) e dino 95% (x0,50)")
    print("  pegar a 100%: o lote que cruza entra inteiro; maior lote = 4 pedra = 6 kg = 12% do jogador (50 kg), 15% do Paquicefalo L10 -> maximo 112% / 115%")
def bolsinha():
    print("bolsinha largada: 300 s (`bolsinha_largada_s`); 8 por jogador (a mais antiga some, com aviso); 60 no mundo; sem colisao")
    print(" pior caso: 8 jogadores x 8 = 64 > 60 -> o teto do mundo vence e apaga a mais antiga do mundo; save: ~0,3 KB por bolsinha de 10 pilhas, 60 = 18 KB [premissa]")
    print(" 6 largadas em 5 min = 1 a cada 50 s: so acontece se a pessoa usa a bolsinha como deposito; o bau existe para isso")
def corpo():
    print("corpo do jogador: 600 s (`corpo_minutos` 20 -> 10). Recuperar: Cama 60 s + ~150 s de ida = 210 s [GDD 12, premissa]")
    for n in (1, 2, 3): print(f"  {n} mortes seguidas: o ultimo corpo e pego em {n*210} s de {600} s ({'sobra '+str(600-n*210)+' s' if n*210<=600 else 'EXPIRA'}) [pior caso: uma ida por vez]")
    print("  a 20 min a margem era de 5,7x (1 corpo) a 1,9x (3 corpos); a 10 min e de 2,9x a 0,95x: o limite de 3 corpos so protege contra a 4a morte, nao contra o relogio")
if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "tudo"
    fn = {"curva": curva, "viagem": viagem, "bolsinha": bolsinha, "corpo": corpo}
    for k in (fn if cmd == "tudo" else [cmd]): print(f"== {k}"); fn[k]()
