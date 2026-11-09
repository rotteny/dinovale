#!/usr/bin/env python3
"""Mapa da ilha (Dino Vale, documentacao/design/mapa-ilha.md). Biblioteca padrao. [proposta] = valor a testar jogando.
Forma = meia-lua (diferenca de dois discos) deformada por ruido fractal, com costa recortada e ilhotas.
Uso: python3 mapa_sim.py [S] forma|travessia|ancora|respawn|curral|recursos|dinos|peso|inicio|mascara|tudo   (S = lado em tiles, padrao 256)"""
import sys, math, random, heapq
from collections import deque, Counter
S = 256
SEED = 0                     # escolhido por escolher_seed() para S=256 e 384 (ver SEEDS)
SEEDS = {192: 1, 256: 1, 384: 1}
WALK, SPRINT = 70 / 16, 120 / 16      # tiles/s
NUCLEO, ANCORA, RONDA, RONCO = 16, 24, 10, 8   # tiles [proposta]; NAO escalam com o mapa (regra de jogo)
NOME = {"C": "Campina", "M": "Mata-baixa", "P": "Pedreira"}

def _h(ix, iy, seed):
    n = (ix * 374761393 + iy * 668265263 + seed * 2147483647) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0
def _vn(x, y, seed):
    ix, iy = math.floor(x), math.floor(y); fx, fy = x - ix, y - iy
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a, b = _h(ix, iy, seed), _h(ix + 1, iy, seed); c, d = _h(ix, iy + 1, seed), _h(ix + 1, iy + 1, seed)
    return (a + (b - a) * fx) + ((c + (d - c) * fx) - (a + (b - a) * fx)) * fy
def ruido(x, y, seed):      # fbm 5 oitavas em [-1, 1]; comprimento de onda base S/5
    t, amp, f, tot = 0.0, 1.0, S / 5.0, 0.0
    for o in range(5):
        t += amp * _vn(x / f * 1.0, y / f * 1.0, seed + 17 * o); tot += amp; amp *= 0.5; f /= 2.0
    return 2 * t / tot - 1
MARGEM = 15      # tiles de terra firme ate a borda do mapa: caminhavel (terra + 3 de raso) fica a >= 12 = meia tela (10 x 5,6) + 2; a camera nunca para [proposta]
def build(seed, amp=0.09):
    c1, r1, c2, r2 = (0.531 * S, 0.5 * S), 0.445 * S, (0.727 * S, 0.5 * S), 0.32 * S
    A = amp * S
    def borda(x, y): return min(x, y, S - 1 - x, S - 1 - y)
    return [[borda(x, y) >= MARGEM and
             min(r1 - math.hypot(x + .5 - c1[0], y + .5 - c1[1]), math.hypot(x + .5 - c2[0], y + .5 - c2[1]) - r2) + A * ruido(x, y, seed) - 0.6 * max(0, 3 * MARGEM // 2 - borda(x, y)) > 0
             for x in range(S)] for y in range(S)]
def ilhotas(land, seed):
    """Ilhotas [proposta]: 10 manchas de 2 a 6 tiles de raio em agua funda (6 a 22 tiles da costa); cenario, sem acesso na 0.2."""
    rng = random.Random(seed * 101 + 7); dl = dist_to(land, True); n = 0; tent = 0
    while n < 10 and tent < 4000:
        tent += 1; cx, cy = rng.randrange(8, S - 8), rng.randrange(8, S - 8); r = rng.uniform(2.5, 6.0)
        if not (6 <= dl[cy][cx] <= 22): continue
        for y in range(max(0, int(cy - r * 1.5)), min(S, int(cy + r * 1.5) + 1)):
            for x in range(max(0, int(cx - r * 1.5)), min(S, int(cx + r * 1.5) + 1)):
                if math.hypot(x - cx, y - cy) <= r * (1 + 0.45 * ruido(x * 3.1, y * 3.1, seed + 99)): land[y][x] = True
        n += 1
    return land
def componentes(land):
    seen = [[False] * S for _ in range(S)]; comp = []
    for y in range(S):
        for x in range(S):
            if land[y][x] and not seen[y][x]:
                q = deque([(x, y)]); seen[y][x] = True; cs = []
                while q:
                    a, b = q.popleft(); cs.append((a, b))
                    for dx in (-1, 0, 1):
                        for dy in (-1, 0, 1):
                            u, v = a + dx, b + dy
                            if 0 <= u < S and 0 <= v < S and land[v][u] and not seen[v][u]: seen[v][u] = True; q.append((u, v))
                comp.append(cs)
    return sorted(comp, key=len, reverse=True)
def dist_to(land, val):
    d = [[9999] * S for _ in range(S)]; q = deque()
    for y in range(S):
        for x in range(S):
            if land[y][x] == val: d[y][x] = 0; q.append((x, y))
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            a, b = x + dx, y + dy
            if 0 <= a < S and 0 <= b < S and d[b][a] > d[y][x] + 1: d[b][a] = d[y][x] + 1; q.append((a, b))
    return d
def faixa(y): return "P" if y < 0.25 * S else ("M" if y < 0.625 * S else "C")

def preparar(side=None):
    global S, SEED, LAND, DSEA, DLAND, COMP, MAIN, ILHOTAS
    if side: S = side
    SEED = SEEDS.get(S, 3); LAND = ilhotas(build(SEED), SEED)
    LAND = [[LAND[y][x] and min(x, y, S - 1 - x, S - 1 - y) >= MARGEM for x in range(S)] for y in range(S)]; COMP = componentes(LAND)
    MAIN = set(COMP[0]); ILHOTAS = [c for c in COMP[1:] if len(c) >= 12]
    DSEA, DLAND = dist_to(LAND, False), dist_to(LAND, True)
def caminhavel(x, y): return LAND[y][x] or DLAND[y][x] <= 3      # praia e raso andam; fundo bloqueia
def dijkstra(src):
    D = {src: 0.0}; pq = [(0, src)]
    while pq:
        d, (x, y) = heapq.heappop(pq)
        if d > D[(x, y)]: continue
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                a, b = x + dx, y + dy
                if (dx or dy) and 0 <= a < S and 0 <= b < S and caminhavel(a, b):
                    nd = d + (1.414 if dx and dy else 1)
                    if nd < D.get((a, b), 1e9): D[(a, b)] = nd; heapq.heappush(pq, (nd, (a, b)))
    return D
def snap(fx, fy, band=None, dmin=3, ocupados=()):
    """Tile de terra firme mais proximo da fracao (fx, fy) de 128x128 (escalada para S)."""
    cx, cy = int(fx * S / 128), int(fy * S / 128)
    for r in range(0, S):
        for dx in range(-r, r + 1):
            for dy in range(-r, r + 1):
                if max(abs(dx), abs(dy)) != r: continue
                x, y = cx + dx, cy + dy
                if 0 <= x < S and 0 <= y < S and (x, y) in MAIN and DSEA[y][x] >= dmin and (band is None or faixa(y) == band) \
                        and all(math.hypot(x - o[0], y - o[1]) >= 6 for o in ocupados): return (x, y)
    raise RuntimeError("sem tile")
def sitios():
    s = {}
    s["inicio"] = snap(70, 98, dmin=2)
    s["paq_tutorial"] = snap(62, 94, dmin=3)
    s["arco"] = snap(61, 91, dmin=2)
    s["tocas"] = {"U1": snap(34, 68, "M"), "U2": snap(20, 56, "M"), "U3": snap(30, 38, "M"), "U4": snap(40, 52, "M"), "U5": snap(46, 34, "M"), "U6": snap(16, 65, "M")}
    # E3 (D-E1): U1 e U6 foram movidas (U1 a 4 tiles da zona segura; U6 estava num tile de Campina). O marco "limiar" do
    # Paquicefalo continua calculado a partir do ponto ANTIGO da U1, para nao mudar o resto do mapa.
    u1, ini = snap(34, 74, "M"), s["inicio"]
    d = math.hypot(ini[0] - u1[0], ini[1] - u1[1]); f = 11 / d
    s["paq_limiar"] = snap((u1[0] + (ini[0] - u1[0]) * f) * 128 / S, (u1[1] + (ini[1] - u1[1]) * f) * 128 / S, dmin=3)
    s["aviso"] = snap(46, 79, dmin=3)
    s["tric"] = [snap(*p, "P") for p in ((30, 28), (40, 18), (50, 22), (62, 26), (75, 16), (88, 18), (96, 19), (104, 24))]
    s["dodo"] = [snap(*p, "M") for p in ((44, 72), (46, 48), (24, 64), (36, 44), (14, 50), (50, 58))]
    s["sal"] = [snap(66, 12, "P"), snap(84, 12, "P")]
    # Portal-de-Pedra: coluna mais estreita (>= 8 tiles) da ponta sul, na metade leste da Campina
    cols = {x: sum(1 for y in range(int(0.625 * S), S) if (x, y) in MAIN and DSEA[y][x] >= 1) for x in range(int(0.55 * S), int(0.92 * S))}
    lest = lambda xx: sum(1 for y in range(int(0.625 * S), S) for x in range(xx, S) if (x, y) in MAIN and DSEA[y][x] >= 2)
    xp = min((w, -x) for x, w in cols.items() if w >= 8 and lest(x) >= 300)
    xp = -xp[1]; ys = [y for y in range(int(0.625 * S), S) if (xp, y) in MAIN and DSEA[y][xp] >= 1]
    s["portal"] = (xp, (ys[0] + ys[-1]) // 2); s["portal_larg"] = len(ys)
    return s
def tudo_marcas(s):
    return {"@": [s["inicio"]], "p": [s["paq_tutorial"]], "q": [s["paq_limiar"]], "A": [s["arco"]], "L": [s["aviso"]], "U": list(s["tocas"].values()),
            "T": s["tric"], "D": s["dodo"], "s": s["sal"], "G": [s["portal"]]}
def ascii_mapa(s):
    cw, ch = S // 64, S // 32; m = tudo_marcas(s); cel = {}
    for k, v in m.items():
        for x, y in v: cel[(x // cw, y // ch)] = k
    isl = {p for c in ILHOTAS for p in c}
    out = []
    for y0 in range(0, S, ch):
        row = ""
        for x0 in range(0, S, cw):
            if (x0 // cw, y0 // ch) in cel: row += cel[(x0 // cw, y0 // ch)]; continue
            c = [(x, y) for y in range(y0, y0 + ch) for x in range(x0, x0 + cw)]; L = [p for p in c if LAND[p[1]][p[0]]]
            if len(L) >= 0.6 * len(c):
                row += "o" if any(p in isl for p in L) else {"C": ":", "M": "%", "P": "#"}[Counter(faixa(y) for x, y in L).most_common(1)[0][0]]
            elif L: row += "o" if any(p in isl for p in L) else ","
            else: row += "~" if min(DLAND[y][x] for x, y in c) <= 3 else " "
        out.append(row.rstrip())
    return "\n".join(out)

def forma():
    n = sum(map(sum, LAND)); praia = sum(1 for y in range(S) for x in range(S) if LAND[y][x] and DSEA[y][x] <= 2)
    raso = sum(1 for y in range(S) for x in range(S) if not LAND[y][x] and DLAND[y][x] <= 3)
    print(f"S={S} seed={SEED}: terra {n} ({n/S/S:.0%}), praia {praia}, raso {raso}, fundo {S*S-n-raso}; ilha principal {len(COMP[0])}, ilhotas (>=12 tiles) {len(ILHOTAS)}: {[len(c) for c in ILHOTAS][:10]}")
    print("bioma (terra):", {NOME[k]: sum(1 for y in range(S) for x in range(S) if LAND[y][x] and faixa(y) == k) for k in "CMP"})
    perim = sum(1 for y in range(S) for x in range(S) if LAND[y][x] and DSEA[y][x] == 1)
    print(f"costa: {perim} tiles de borda; razao costa/raiz(area) = {perim/math.sqrt(n):.1f} (disco perfeito = {2*math.pi**0.5:.1f}; quanto maior, mais recortada)")
    print(ascii_mapa(sitios()))
def travessia():
    s = sitios(); D = dijkstra(s["inicio"]); far = max(D, key=D.get)
    print(f"maior caminho a pe do inicio: {D[far]:.0f} tiles = {D[far]/WALK:.0f} s a pe; com sprints (4 s de 7,5 tiles/s a cada 9,3 s): ~{D[far]/ (WALK*0.88 + 0.12*0 + (4*SPRINT-4*WALK)/9.3):.0f} s (ponta {far})")
    for k, p in (("Paq. tutorial", s["paq_tutorial"]), ("Paq. limiar", s["paq_limiar"]), ("toca U1", s["tocas"]["U1"]), ("toca U6", s["tocas"]["U6"]), ("toca U4", s["tocas"]["U4"]),
                 ("toca U2", s["tocas"]["U2"]), ("toca U3", s["tocas"]["U3"]), ("toca U5", s["tocas"]["U5"]), ("Triceratops 1", s["tric"][0]), ("Triceratops 8", s["tric"][7]), ("Sal", s["sal"][0])):
        print(f"  {k:14} {D[p]:6.0f} tiles  {D[p]/WALK:5.0f} s")
    print(f"linha reta inicio -> ponta: {math.hypot(far[0]-s['inicio'][0], far[1]-s['inicio'][1]):.0f} tiles")
def lente(r1, r2, d):
    if d >= r1 + r2: return 0.0
    if d <= abs(r1 - r2): return math.pi * min(r1, r2) ** 2
    a = r1*r1*math.acos((d*d+r1*r1-r2*r2)/(2*d*r1)); b = r2*r2*math.acos((d*d+r2*r2-r1*r1)/(2*d*r2))
    return a + b - 0.5*math.sqrt((-d+r1+r2)*(d+r1-r2)*(d-r1+r2)*(d+r1+r2))
def ancora():
    s = sitios(); ini = s["inicio"]
    nuc = sum(1 for y in range(S) for x in range(S) if LAND[y][x] and DSEA[y][x] >= 2 and math.hypot(x-ini[0], y-ini[1]) <= NUCLEO)
    print(f"nucleo seguro R={NUCLEO}: {nuc} tiles de terra firme; ancora {ANCORA}; ronda {RONDA}; ronco {RONCO}")
    for k, t in s["tocas"].items():
        d = math.hypot(t[0]-ini[0], t[1]-ini[1]); print(f"  {k} {t}: {d:5.1f} do inicio; borda da ancora a {d-ANCORA:5.1f} (precisa >= {NUCLEO}) {'OK' if d-ANCORA >= NUCLEO else 'FALHA'}")
    u1 = s["tocas"]["U1"]
    for nome, p in (("Paq. limiar", s["paq_limiar"]), ("Paq. tutorial", s["paq_tutorial"])):
        d = math.hypot(p[0]-u1[0], p[1]-u1[1]); print(f"  {nome}: a {d:.1f} da toca U1; fracao da ronda a <= {RONCO} do dormindo: {lente(RONDA, RONCO, d)/(math.pi*RONDA**2):.0%}")
    p = s["paq_limiar"]; d1 = math.hypot(p[0]-u1[0], p[1]-u1[1]); d = math.hypot(p[0]-ini[0], p[1]-ini[1])
    print(f"  fuga do Limiar: sair da ancora da U1 = {ANCORA-d1:.0f} tiles = {(ANCORA-d1)/WALK:.1f} s a pe (o Utahraptor, 5,6 tiles/s, para na ancora); o Limiar fica a {d:.0f} tiles do inicio ({d/WALK:.0f} s)")
    far = min(math.hypot(t[0]-ini[0], t[1]-ini[1]) - ANCORA for t in s["tocas"].values())
    print(f"  area livre de Utahraptor: nenhum ponto a menos de {far:.0f} tiles do inicio fica dentro de alguma ancora")
def sorteavel():
    r = {}
    for y in range(S):
        for x in range(S):
            if (x, y) in MAIN and DSEA[y][x] >= 2: r.setdefault(faixa(y), []).append((x, y))
    return r
def respawn(runs=3000):
    random.seed(5); cam = sorteavel(); s = sitios(); tocas = s["tocas"]; tric = s["tric"]
    def sorteio(reg):
        ag = []
        for k, t in tocas.items():
            for _ in range(1 if k == "U1" else random.choice((1, 2))):
                a = random.uniform(0, 6.2832); r = RONDA * math.sqrt(random.random()); ag.append((t[0]+r*math.cos(a), t[1]+r*math.sin(a)))
        ok = lambda p: all(math.hypot(p[0]-a[0], p[1]-a[1]) >= 16 for a in ag) and all(math.hypot(p[0]-q[0], p[1]-q[1]) >= 8 for q in tric)
        return ok(random.choice(cam[reg])), any(ok(random.choice(cam[reg])) for _ in range(30))
    for reg in "CMP":
        r = [sorteio(reg) for _ in range(runs)]
        print(f"  {NOME[reg]:10} {len(cam[reg]):5} tiles; 1 sorteio recusado em {1-sum(a for a,_ in r)/runs:4.0%}; ponto reserva em {1-sum(b for _,b in r)/runs:5.2%} (30 sorteios)")
    for reg in "MP":
        pts = list(tocas.values()) + ([q for q in tric] if reg == "P" else [])
        best = max((min(math.hypot(x-t[0], y-t[1]) for t in pts), (x, y)) for x, y in cam[reg][::7] if DSEA[y][x] >= 3)
        print(f"  melhor ponto reserva {NOME[reg]}: {best[1]} a {best[0]:.0f} tiles da toca/Triceratops mais proxima")
    ini = s["inicio"]; print("  reserva Campina: ponto fixo no nucleo, ex.", snap(62 , 100, "C", dmin=6))
def curral():
    s = sitios(); p = s["portal"]
    area = sum(1 for y in range(S) for x in range(S) if (x, y) in MAIN and faixa(y) == "C" and x >= p[0] and DSEA[y][x] >= 2)
    pesc = s["portal_larg"]
    print(f"  Portal-de-Pedra em {p}: terra firme a leste dele {area} tiles; pescoco {pesc} tiles (as 2 formacoes deixam vao de 4 tiles)")
    print("  vao de 4 tiles: 3 cerca x 2 madeira + 1 portao x 4 = 10 madeira = 27 s; curral artificial de area igual: perimetro ~ 4*raiz(area) pecas x 2 madeira")
    print(f"  = {4*math.sqrt(area):.0f} pecas = {8*math.sqrt(area):.0f} madeira = {8*math.sqrt(area)*8/3/60:.1f} min de coleta [calculado]")
def contagens():
    """Contagens por bioma proporcionais a terra firme (base: ilha de 128x128 com C 2051, M 2024, P 1351 tiles)."""
    base = {"C": 2051, "M": 2024, "P": 1351}
    terra = {k: sum(1 for y in range(S) for x in range(S) if LAND[y][x] and faixa(y) == k) for k in "CMP"}
    return {k: terra[k] / base[k] for k in "CMP"}, terra
NOS = {   # id: (item, por colheita, s, respawn s, {bioma: n na ilha de 128}, fonte)
 "tree (coletavel)":  ("madeira", 3, 8, 480, {"C": 88, "M": 144, "P": 24}, "codigo; TODAS coletaveis, sem arvore de cenario (06/11, dono)"),
 "bush baga (+2 fibra)": ("baga", 3, 12, 240, {"C": 14, "M": 8}, "unico: 3 baga em 9 s + 2 fibra em 3 s"),
 "bush sono (+2 fibra)": ("Cochilo", 3, 16, 420, {"M": 10}, "unico: 3 frutas em 12 s + 2 fibra em 4 s"),
 "rock (so Picareta)": ("pedra", 4, 10, 600, {"C": 6, "M": 8, "P": 30}, "codigo; Soco nao coleta"),
 "fern":              ("samambaia", 3, 12, 240, {"C": 10, "M": 8}, "premissa"),
 "tuber":             ("tuberculo", 2, 16, 420, {"C": 8, "M": 4}, "premissa"),
 "salt_vein":         ("sal-de-veio", 2, 20, 480, {"P": 8}, "premissa"),
 "iron_seam (M4)":    ("minerio", 2, 14, 900, {"P": 8}, "proposta"),
}
def recursos():
    esc, terra = contagens(); print("escala por bioma (terra nova / terra de 128):", {NOME[k]: round(v, 2) for k, v in esc.items()})
    print(f"{'no':22}{'item':14}{'total':>6}{'estoque':>9}{'rep/min':>9}")
    tot_nos = 0
    for k, (item, y, sec, rs, d, f) in NOS.items():
        n = sum(round(v * esc[b]) for b, v in d.items()); tot_nos += n
        print(f"{k:22}{item:14}{n:6}{n*y:9}{n*y/(rs/60):9.1f}  {f}")
    print(f"nos coletaveis (sem pedras avulsas): {tot_nos}")
    s = sitios(); D = dijkstra(s["inicio"]); far = max(D, key=D.get)
    avul_n, avul_t = 10, math.ceil(D[far] / 30) + 4
    print(f"pedras avulsas: {avul_n} no nucleo (volta em 300 s) + {avul_t} na trilha ate a ponta ({D[far]:.0f} tiles: 1 a cada 30, mais 4 na entrada da Pedreira; volta em 600 s) = {avul_n+avul_t}")
    arv = sum(round(v * esc[b]) for b, v in NOS["tree (coletavel)"][4].items()); print(f"arvores: {arv} coletaveis (todas; sem arvore de cenario, as formacoes rochosas seguem fixas)")
    print("Cochilo: 1 dino dormindo gasta 2 a 3 frutas/min; oferta = n arbustos x 3 / 7 min")
def dinos():
    esc, terra = contagens(); tot = sum(terra.values())
    # alvo por especie (grupos de GDD 6.7) para a ilha de 256: Dodo 6 zonas x 12; Paq grupos de 1 a 3; Parass manadas de 3 a 5; Tric solitario; Utahraptor por toca
    f = (S / 256) ** 2
    pop = {"Dodo": ("diminuto", round(72 * f)), "Paquicefalo": ("pequeno", round(56 * f)), "Parassaurolofo": ("medio", round(40 * f)),
           "Triceratops": ("grande", round(8 * f)), "Utahraptor": ("medio, ameaca", round(10 * f))}   # portes do dono (GDD 4.2); Triceratops = grande [assumido]
    n = sum(v[1] for v in pop.values()); herb = n - pop["Utahraptor"][1]
    print(f"S={S}: terra {tot}; dinos {n} (herbivoros {herb}); 1 dino a cada {tot/n:.0f} tiles de terra; tela 640x360 = 900 tiles -> ~{900*n/tot:.1f} por tela em media")
    for k, (t, c) in pop.items(): print(f"  {k:15} {c:4}  {t}")
    por = Counter()
    for k, (t, c) in pop.items(): por[t.split(',')[0]] += c
    print("  por faixa de tamanho:", {k: f"{v} ({v/n:.0%})" for k, v in por.items()})
    for r, nome in ((24, "ativo (IA e fisica)"), (48, "distante (so dados, passeio a cada 2 s)")):
        print(f"  raio {r} tiles: {math.pi*r*r:.0f} tiles de area -> {math.pi*r*r*n/tot:.0f} dinos em media, ~{math.pi*r*r*n/tot*2:.0f} no pior caso (2x) - {nome}")
    print("  teto `dinos_ativos_max` = 32; os mais distantes viram `distante` ao passar do teto")
    print("  percepcao: 32 ativos x (1 jogador + vizinhos por grade de 8 tiles) a cada 0,5 s = ~64 a 300 checagens/s; irrelevante contra o A* e a fisica")
def camera():
    """Viewports candidatos (tile 16, humano 32 px, 4 e 8 px/s do GDD 6.7). Vigente: 320x180."""
    WS, CH = 70 / 16, 90 / 16                      # jogador andando e perseguicao do Agressivo, tiles/s
    SPR = 120 / 16
    print("viewport    tiles      area  720p 1080p  meia L/A   aviso L (s)  aviso A  humano%  gigante 96 px (alt)  vistos de 1 vez")
    for w, h in ((640, 360), (427, 240), (320, 180)):
        tw, th = w / 16, h / 16
        ex = lambda W: ("%dx" % (W // w) if W % w == 0 else "-")
        hl, ha = tw / 2 - RONCO, th / 2 - RONCO
        print(f"{w}x{h:<4} {tw:5.1f}x{th:4.1f} {tw*th:6.0f}  {ex(1280):>4} {ex(1920):>5}  {tw/2:4.1f}/{th/2:4.1f}   {hl:4.1f} ({max(0,hl)/WS:3.1f} s)   {ha:5.1f}   {32/h:5.1%}   {96/h:5.0%}")
    print("-- 320x180: tempo de reacao ao Utahraptor (percepcao 8 tiles, perseguicao 5,6 tiles/s, jogador 4,4 andando / 7,5 em sprint por 4 s)")
    tw, th = 20, 11.25
    print(f"  aparece na borda lateral (10) -> percebe (8): {(10-8)/WS:.2f} s se o jogador anda ate ele; na vertical (5,6 < 8) ele percebe FORA da tela")
    for rot, lim in (("elipse 8 x 5", 5.0), ("elipse 8 x 5 + sinal a 12", 5.0)):
        pass
    print(f"  percebe -> contato (7 tiles a 5,6 t/s, jogador parado): {7/CH:.2f} s; fugindo andando: fecha 1,25 t/s = {7/(CH-WS):.1f} s; sprint abre {(SPR-CH)*4:.1f} tiles em 4 s")
    print(f"  sinal de borda a 12 tiles (fora da tela): avisa {(12-8)/CH:.2f} s antes da percepcao com ele correndo, {(12-8)/2.5:.1f} s se ele ronda (40 px/s)")
    print("-- sensacao de tamanho em telas (tela 20x11,25 = 225 tiles; maior caminho / 20)")
    for side, terra, trajeto, dinos in ((192, 12588, 226, 207), (256, 21857, 280, 186), (384, 48400, 429, 418)):
        print(f"  S={side}: terra {terra/225:5.0f} campos de visao de terra; trajeto {trajeto/WS:3.0f} s a pe; comparar 640x360: 256 = {21857/900:.0f} telas de terra, {280/40:.1f} de trajeto")
    print("-- densidade e zona ativa (area do circulo de raio r; pior caso = 2x a media)")
    for side, terra, dinos, label in ((192, 12588, 207, "192 com 207 dinos (1 a cada 61)"), (256, 21857, 186, "256 com 186 (1 a cada 118)"), (256, 21857, 360, "256 com 360 (1 a cada 61)")):
        for r in (16, 20, 24):
            print(f"  {label:34} raio {r}: {math.pi*r*r*dinos/terra:5.1f} ativos em media, ~{2*math.pi*r*r*dinos/terra:4.0f} no pior caso; por tela {225*dinos/terra:3.1f} (320x180), {900*dinos/terra:3.1f} (640x360)")
def peso():
    for side in (192, 256, 384):
        preparar(side); n = sum(map(sum, LAND)); cel = side * side
        esc, terra = contagens(); nos = sum(round(v * esc[b]) for k, (_, _, _, _, d, _) in NOS.items() if k != "iron_seam (M4)" for b, v in d.items())
        sit = sitios(); D = dijkstra(sit["inicio"]); far = max(D, key=D.get); f = (side / 256) ** 2
        dn = round(186 * f)
        print(f"S={side}: {cel:,} tiles/camada x 3 camadas x ~32 B = {cel*3*32/1e6:4.1f} MB; AStarGrid2D {cel:,} pontos ~{cel*100/1e6:4.1f} MB; terra {n:,}; nos de recurso ~{nos}; dinos ~{dn}; maior trajeto {D[far]:.0f} tiles = {D[far]/WALK:.0f} s a pe")
        print(f"        save: nos esgotados (12 B) ate {nos*12/1000:.0f} KB; dinos (~150 B) {dn*150/1000:.0f} KB; mascara {cel/8/1000:.0f} KB; tempo de montar o A* (~1 us/ponto em GDScript e ~0,5 us em C++) {cel*1e-6:.2f} a {cel*3e-6:.2f} s")
    preparar(256)
def inicio():
    """Primeiros 5 minutos (tempos em s). Premissas: andar 4,375 tiles/s; pedra avulsa 1 s; Soco na arvore 8 s por 3 madeira; Machado 4 s; craft a mao 4 s."""
    t = 0; log = []
    def passo(nome, dt, nota=""): nonlocal t; t += dt; log.append((t, nome, nota))
    passo("5 pedras avulsas (6 tiles entre elas)", 5 * 1 + 5 * 6 / WALK, "5 pedra, 7,5 kg")
    passo("arbusto de baga", 6 / WALK + 12, "3 baga + 2 fibra (fome +30)")
    passo("2 arvores no Soco", 8 / WALK + 8 + 3 / WALK + 8, "6 madeira; -2 de vida (1 por colheita)")
    passo("craft Machado e Picareta", 8, "3m+2p+1f e 3m+3p+1f; sobra 0 pedra, 0 madeira, 0 fibra")
    passo("32 madeira com Machado (11 arvores)", 11 * (4 + 3 / WALK), "Machado 2x o Soco; sem dano")
    passo("1 no de pedra com Picareta", 5 + 4 / WALK, "4 pedra")
    passo("construir abrigo (13 pecas)", 13 * 3, "[premissa 3 s por peca]")
    passo("Fogueira + Bancada (12 madeira, 5 pedra)", 4 * (4 + 3 / WALK) + 2 * (5 + 4 / WALK) + 8, "")
    passo("2 arbustos para o Saco (4 fibra) e mais", 2 * (12 + 6 / WALK), "")
    for tt, n, nota in log: print(f"  {tt:5.0f} s  ({tt/60:3.1f} min)  {n}  {nota}")
    print(f"  Stamina do Soco: 8 s x 4/s = 32 por arvore, regenera 15/s; nao esgota. Vida: -2 no inicio, regeneracao fora de combate repoe.")
    print("  Pedras avulsas necessarias ate a 1a Picareta e o 1o Machado: 5 (3 + 2). Gasto antes da Picareta (Fogueira 3 + Bancada 2 + Pilao 2 + abrigo 4 = 11) so atrasa: 10 no nucleo voltam em 300 s")
def mascara():
    for y in range(S): print("".join(("#" if LAND[y][x] else ("~" if DLAND[y][x] <= 3 else ".")) for x in range(S)))
if __name__ == "__main__":
    a = sys.argv[1:]
    side = int(a.pop(0)) if a and a[0].isdigit() else 256
    preparar(side)
    cmd = a[0] if a else "tudo"
    fn = {"camera": camera, "forma": forma, "travessia": travessia, "ancora": ancora, "respawn": respawn, "curral": curral, "recursos": recursos, "dinos": dinos, "peso": peso, "inicio": inicio, "mascara": mascara}
    for k in ([x for x in fn if x not in ("mascara", "peso")] if cmd == "tudo" else [cmd]): print(f"== {k}"); fn[k]()
