#!/usr/bin/env python3
"""Montaria e comando do dino domado (Dino Vale, GDD 5.22 e 6.11). Biblioteca padrao. Uso: python3 montaria_sim.py velocidade|duelo
Velocidades da especie [premissa]: as de perseguicao ou fuga da Conduta (GDD 6.7) servem de proxy; jogador 70 andando, 120 correndo (GDD 5.1)."""
import sys
ESP = {"Parassaurolofo": 75, "Utahraptor": 90, "Triceratops": 90}
MULT = 1.3                       # [premissa] montaria_velocidade_mult
def sprint_medio():
    # stamina 100; sprint -25/s; regenera 15/s depois de 0,5 s sem sprint; retoma sprint a 20 (GDD 5.8)
    t = dx = 0.0; st = 100.0; dt = 0.01; sprint = True; wait = 0.0
    while t < 600:
        if sprint and st > 0: st -= 25 * dt; dx += 120 * dt
        else:
            if sprint: sprint = False; wait = 0.5
            dx += 70 * dt
            wait -= dt
            if wait <= 0: st = min(100, st + 15 * dt)
            if st >= 20 and wait <= 0: sprint = True
        t += dt
    return dx / t
def velocidade():
    m = sprint_medio()
    print(f"Jogador: anda 70, correndo sustentado (ciclo de Stamina) ~{m:.0f} px/s, rajada de 4 s a 120")
    for n, v in ESP.items():
        vm = v * MULT
        print(f"  {n:15} especie {v}, montado x{MULT} = {vm:5.1f} px/s | 40 tiles (640 px): a pe {640/70:4.1f} s, correndo {640/m:4.1f} s, montado {640/vm:4.1f} s | ganho sobre correr {100*(vm/m-1):+.0f}%")
    print("Sem o x1,3 a montaria seria mais lenta que correr (75 a 90 contra ~85 sustentado): nao teria motivo. O ganho real e andar sem gastar Stamina.")
def duelo():
    d, cd, vida = 11.25, 1.5, 126      # Utahraptor L20: mordida, intervalo, vida (GDD 5.11 e armas)
    print(f"Utahraptor L20 montado contra Utahraptor L20 selvagem: cada um tira {d/cd:.1f} dps de {vida} de vida = {vida/(d/cd):.0f} s para matar; empate. Montar nao da vitoria gratis; Dano em pontos decide.")
    print("Contra Dodo (24): 3 mordidas, 3 s (Lanca: 2 golpes, 1,8 s). Contra Triceratops L24 (investida 31): perde sem Dano ou Vida.")
{"velocidade": velocidade, "duelo": duelo}[sys.argv[1]]()
