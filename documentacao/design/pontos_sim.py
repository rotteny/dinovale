#!/usr/bin/env python3
"""Pontos de atributo (Dino Vale 0.2). Biblioteca padrao. Uso: python3 pontos_sim.py xp|build|dino
Premissas marcadas [premissa]; o que e calculo sai daqui."""
import sys, math
PT = 0.06                      # valor de 1 ponto: 6% do valor base do atributo (jogador e dino)
CAP_JOG, MULT, DINO_MAX = 20, 2.0, 50   # tetos 06/11 (GDD 5.16): dino = min(2 x nivel final, 50); CAP_EXTRA (captura + 10) removido
def xp_jog(L): return 30 + 15 * (L - 1)        # XP de L para L+1
def xp_dino(g): return 20 + 10 * g              # g = niveis extras ja ganhos
def acum(f, n): return sum(f(i) for i in range(1, n + 1)) if f is xp_jog else sum(f(i) for i in range(0, n))
def auto(L, k): return max(0.5 if k == .04 else .7, 1 + k * (L - 10)) - 1   # bonus automatico do nivel de captura

def xp():
    print("Jogador: XP p/ subir e acumulado; minutos por nivel em 3 ritmos de XP/min [premissa: ruim 8, medio 13, bom 20]")
    for L in (2, 5, 10, 15, 20, 25, 30):
        tot = acum(xp_jog, L - 1)
        print(f"  nivel {L:2}: acumulado {tot:5} XP | pontos {L-1:2} | " + "  ".join(f"{r}/min={tot/r:6.0f} min ({tot/r/60:4.1f} h)" for r in (8, 13, 20)))
    print("Fontes [premissa]: no coletar 1; craftar 2 (1a vez da receita 15); domar 15+3*nivel final; matar 0")
    print("  45 min medios: 6 nos/min*45=270 + 1 craft/min*45*2=90 + 4 domas (nivel 15)*60=240 -> %d XP (%.1f/min)" % (600, 600/45))
    print("Dino: XP p/ subir g->g+1 = 20+10g; ate g=10: acumulado", acum(xp_dino, 10), "XP; a 15 XP/min (13 do jogador + 2 de oficio):", round(acum(xp_dino, 10)/15), "min")

SP = {  # torpor base, vida, dano por mordida, intervalo (s), nivel tipico [premissa de dano]
 "Paquicefalo L12": (100, 80, 6, 2.0, 12), "Utahraptor L20": (120, 80, 8, 1.5, 20), "Triceratops L28": (160, 300, 20, 2.5, 28)}
BASTAO, CD = 30, 0.7   # torpor por golpe e cooldown (sem Lanca)
def build():
    print("Camada 1: sem Lanca. Jogador nivel 20 (19 pontos), Bastao 30 torpor/0,7 s. Dano do jogador = +6%/ponto no dano E NO TORPOR do golpe. Sem esquiva.")
    print("Bastao mata? Utahraptor L10: 80/2 = 40 golpes, %.1f s, %.0f mordidas de 8 = %.0f dano (vida 100): NAO" % (39*CD, 39*CD//1.5, 39*CD//1.5*8))
    builds = {"sem pontos": (0,0,0,0), "tudo Dano": (0,19,0,0), "tudo Vida": (19,0,0,0), "tudo Stamina": (0,0,19,0), "tudo Peso": (0,0,0,19), "equilibrado": (5,5,5,4)}
    for sp, (tor, hp, dmg, dcd, L) in SP.items():
        T = tor * max(0.7, 1 + 0.02 * (L - 10)); D = dmg * (1 + 0.04 * (L - 10))
        print(f" {sp}: torpor {T:.0f}, mordida {D:.1f} por {dcd}s")
        for n, (v, d, s_, p) in builds.items():
            hit = BASTAO * (1 + PT * d); hits = math.ceil(T / hit); ttk = (hits - 1) * CD
            bites = int(ttk // dcd); pv = 100 * (1 + PT * v)
            print(f"   {n:12} golpe {hit:5.1f} golpes {hits:2} nocaute {ttk:4.1f}s | mordidas {bites} = {bites*D:5.1f} ({100*bites*D/pv:3.0f}% de {pv:3.0f}) | sprint {4*(1+PT*s_):4.1f}s peso {50*(1+PT*p):5.1f}kg")
def protecao():
    print("Proteger o dormindo (Utahraptor L20 mira Paquicefalo dormindo de 86 vida): aviso 3 s, mordida a cada 1,5 s; custo em E por mordida = 8 + 0,5 x %vida")
    D = 8 * 1.4; E_bite = 8 + 0.5 * 100 * D / 86
    print("  mordida %.1f dano = %.1f%% da vida -> %.1f E por mordida" % (D, 100*D/86, E_bite))
    for dano_pts in (0, 10):
        hit = BASTAO * (1 + PT * dano_pts); hits = math.ceil(144 / hit)
        for bando in (1, 2, 3):
            for nome, r in (("bom (jogador a 2 tiles)", 0.0), ("medio (+2 s)", 2.0), ("ruim (+4 s)", 4.0)):
                t_ko = r + bando * (hits - 1) * CD + (bando - 1) * 0.5   # 0,5 s para trocar de alvo [premissa]
                bites = 0 if t_ko < 3 else int((t_ko - 3) // 1.5) + 1
                bites *= 1 if bando == 1 else 1   # um mordedor por vez no dormindo [premissa]
                print(f"  Dano {dano_pts:2} pts, bando {bando}, {nome:24}: nocaute de todos em {t_ko:4.1f} s -> {bites} mordidas = -{bites*E_bite:4.1f} E")
    print("  Nocautear dura 144/1,4 = ~103 s de sono (queda 1,2/s no L20); domar o Paquicefalo em C leva 40 s: o ameacador nao acorda antes.")

def dino():
    print("Dino no teto de evolucao: min(2 x nivel final, 50); auto do nivel final + pontos (1 por nivel); vida/dano/peso x base")
    for nome, base_L, L_final, peso in (("Paquicefalo (L12, E100 -> 18)", 12, 18, 40), ("Utahraptor (L20, E100 -> 30)", 20, 30, 0), ("Triceratops (L28, E100 -> 42)", 28, 42, 120)):
        a, ap = auto(L_final, .04), auto(L_final, .03)
        npt = int(min(MULT * L_final, DINO_MAX) - L_final); print(f"  {nome}: teto {int(min(MULT * L_final, DINO_MAX))}, {npt} pontos")
        for n, (v, d, p) in {"sem pontos": (0,0,0), "tudo Dano": (0,npt,0), "tudo Vida": (npt,0,0), "tudo Peso": (0,0,npt), "4/3/3": (round(.4*npt), round(.3*npt), npt-round(.4*npt)-round(.3*npt))}.items():
            print(f"  {nome:30} {n:10} vida x{1+a+PT*v:4.2f} dano x{1+a+PT*d:4.2f} peso x{1+ap+PT*p:4.2f}" + (f" = {peso*(1+ap+PT*p):5.1f} kg" if peso else ""))
    print("Teto de nivel do dino = min(2 x nivel final, dino_nivel_max 50 no MVP). Eficiencia (1,5x) so vale na domesticacao.")
    print("Viagem de Peso: 40 tiles = 640 px / 75 px/s = 8,5 s ida; volta 8,5 s; ~20 s com carga. 3 abrigos = 114 kg: Paq L18 49,6 kg + jogador 50 = 99,6 -> 2 viagens; com 10 pontos em Peso (73,6 kg) = 123,6 -> 1 viagem. Ganho ~20 s por obra.")
{"xp": xp, "build": build, "dino": dino, "protecao": protecao}[sys.argv[1] if len(sys.argv) > 1 else "xp"]()
