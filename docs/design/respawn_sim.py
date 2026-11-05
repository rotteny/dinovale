#!/usr/bin/env python3
"""Respawn, Saco e Cama (Dino Vale, GDD 12). Biblioteca padrao. [premissa] = valor a testar jogando.
Uso: python3 respawn_sim.py ponto|custo|espera"""
import sys, random, math
MAPA = 128                      # tiles (GDD 4)
REGIAO = 70 * 70                # tiles caminhaveis por regiao [premissa: ~1/3 do mapa]
TENT = 30                       # sorteios antes do ponto reserva
def ponto():
    """Chance de cair no ponto reserva: N agressivos espalhados, raio minimo R."""
    random.seed(7)
    print(f"regiao 70x70, {TENT} tentativas; falha = TODAS as tentativas dentro do raio de algum agressivo")
    for R in (16, 24):
        for n in (2, 4, 8, 16):
            falhas = 0; tot = 4000
            for _ in range(tot):
                ds = [(random.uniform(0, 70), random.uniform(0, 70)) for _ in range(n)]
                ok = False
                for _ in range(TENT):
                    x, y = random.uniform(0, 70), random.uniform(0, 70)
                    if all(math.hypot(x - a, y - b) >= R for a, b in ds): ok = True; break
                falhas += (not ok)
            cob = min(1.0, n * math.pi * R * R / REGIAO)
            print(f"  R={R:2} tiles, {n:2} agressivos: cobertura max {cob:4.0%}, reserva em {falhas/tot:6.2%} dos respawns")
def custo():
    """Custo em minutos de jogo (coleta: fibra 3 s/un, madeira 8 s por 3, GDD 7)."""
    fibra, mad = 3.0, 8 / 3
    for nome, f, m in (("Saco", 8, 0), ("Cama", 12, 8)):
        t = f * fibra + m * mad
        print(f"  {nome}: {f} fibra + {m} madeira = {t:4.0f} s de coleta ({t/60:3.1f} min); abrigo minimo = 32 madeira + 4 pedra = ~3 a 4 min")
    print("  Saco nao poupa tempo (cruzar o mapa leva 29 s): vale pela POSICAO, um ponto de volta numa expedicao")
    print("  Cama (~1 min) vs recuperar o corpo (2 a 3 min, GDD 12): Cama perto da base poupa a ida da Campina ate o corpo")
def espera():
    """Espera de 60 s da Cama: quando importa."""
    print("  espera 60 s so morde em morte em sequencia (< 60 s apos renascer); recuperar o corpo leva 120 a 180 s")
    print("  salvar a restante (nao o instante): 'espera_restante_s'; o relogio so corre com o mundo rodando")
    print("  autosave: perda maxima em queda = 300 s = 5 min; 12 saves/h por intervalo, mais os eventos")
{"ponto": ponto, "custo": custo, "espera": espera}[sys.argv[1]]()
