#!/usr/bin/env python3
"""Exporta a ilha Lunata (documentacao/design/mapa-ilha.md) para o dado versionado do jogo.

A FORMA vem de `mapa_sim.py` (diferenca de dois discos + ruido fractal, semente fixa). Este script
junta o que o jogo precisa e o simulador so contava: o terreno por tile, o inicio, os marcos, a
posicao dos nos de recurso (toda arvore e coletavel; so as formacoes rochosas sao cenario) e as vagas de bando.
O jogo NAO gera o mapa ao rodar: le `game/data/world/lunata.json`, que sai daqui.
Biblioteca padrao apenas. Mesma semente, mesmo arquivo (byte a byte).

Uso (da raiz do repositorio):
    python3 documentacao/design/mapa_export.py            # grava game/data/world/lunata.json
    python3 documentacao/design/mapa_export.py --check    # falha se o arquivo gravado difere do que sairia daqui
    python3 documentacao/design/mapa_export.py --primeira-geracao   # so quando nao ha arquivo anterior com ids

Ids estaveis (ADR-007): cada no de recurso ganha um id opaco, gravado em campo PARALELO (`node_ids`, mesma ordem
das listas de `nodes`; o formato das listas nao muda). Ao reexportar, le o arquivo anterior e herda o id do ponto
do mesmo tipo que ficou igual ou andou ate ID_RADIUS tiles. Ponto novo ganha id novo; o contador (`id_counter`)
nunca volta, entao id aposentado nao e reaproveitado. `content_hash` e o SHA-256 (16 hex) do conteudo canonico,
sem `revision` nem ele mesmo.
Vagas de bando e regioes (ADR-007, emenda de 07/11): `spawn_slots` (id `g<n>`, especie, regiao, tamanho) e
`spawn_regions` (mascara de tiles validos por regiao, runs `[y, x0, x1]` com x1 INCLUSIVO, ordenadas por y e x, ja
filtradas por bioma e sem os tiles bloqueados por no/cenario). A posicao do bando NAO esta no mapa: o jogo sorteia.
Os pontos antigos (`spawns`, `spawn_ids`) SAIRAM do arquivo em 07/11: o jogo le so `spawn_slots`/`spawn_regions`.
`id_counter.w` (contador dos ids `w<n>` dos pontos antigos) fica no arquivo so como HISTORICO, sem uso: o jogo nao
o le e nada mais o incrementa; nao reutilize o prefixo `w`. Id `g` nunca e reaproveitado (`id_counter.g`). Vaga
corresponde por (especie, regiao), na ordem dos ids; tamanho diferente mantem o id. Dodo e Triceratops ainda nao
existem em `game/data/`: as vagas saem mesmo assim e o jogo ignora especie desconhecida.
Testes: python3 -m unittest documentacao/design/mapa_export_test.py (ou rode o arquivo de teste direto).
"""
import hashlib
import json
import functools
import math
import os
import random
import sys
from collections import deque

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mapa_sim as m  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "game", "data", "world", "lunata.json")
FORMAT = 2  # 2: vagas de bando com size_min/size_max (o jogo recusa o formato 1)
REVISION = 2  # 2: todas as arvores coletaveis, sem arvore de cenario (os ids dos nos mudaram)
TILE = 16
# Indices 0 a 5 sao os terrenos de `terreno.json`; 6 e a agua funda do anel de 2 tiles junto ao raso (unica com colisao).
TERRAINS = ["agua_funda", "agua_rasa", "praia", "campina", "mata_baixa", "pedreira", "agua_funda_anel"]
BIOME_CODE = {"C": 3, "M": 4, "P": 5}
# Retangulo dos pes (largura, altura) em px, centrado em (0, -altura/2) acima da origem. Igual ao dado do jogo.
FEET = {"tree": (12, 8), "rock": (24, 12), "bush": (10, 6), "formation_a": (52, 14), "formation_b": (84, 12),
        "formation_c": (48, 12)}
START_CLEAR = 8        # tiles sem arvore nem rocha em volta do inicio
ID_RADIUS = 2.0        # tiles: ponto do mesmo tipo ate aqui do anterior herda o id
TUTORIAL_KEY = "paquicefalo_tutorial"
# Regioes: nome -> terrenos (codigos de TERRAINS) cujos tiles entram na mascara.
REGIONS = {"r_campina": [3], "r_mata": [4], "r_pedreira": [5], "r_campina_mata": [3, 4]}
# Vagas de bando (bandos-e-dano-em-area.md 3 e 3.1): especie -> (regiao, tamanho_min, tamanho_max, tamanhos de cada vaga).
SLOT_TABLE = [
    ("dodo", "r_campina", 2, 4, [2, 3, 4, 3, 3, 2, 4, 3]),
    ("paquicefalo", "r_campina_mata", 3, 4, [3, 4] * 10),
    ("utahraptor", "r_mata", 2, 3, [3, 3, 2, 2]),
    ("triceratops", "r_pedreira", 1, 2, [2, 2, 1, 1]),
]
SPACING = {"tree": 3.0, "rock": 3.0, "bush": 2.0, "formation": 4.0}


def feet_rect(kind, x, y):
    w, h = FEET[kind]
    cx, cy = x * TILE + 8, y * TILE + 8
    return (cx - w / 2, cy - h, cx + w / 2, cy)


class Placer:
    def __init__(self, rng):
        self.rng = rng
        self.items = []      # (kind, x, y)
        self.grid = {}       # (x//8, y//8) -> [(kind, x, y)]
        self.blocked = set()

    def free(self, kind, x, y, gap):
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                for (_, ox, oy) in self.grid.get((x // 8 + dx, y // 8 + dy), ()):
                    if math.hypot(ox - x, oy - y) < gap:
                        return False
        return True

    def add(self, kind, x, y):
        self.items.append((kind, x, y))
        self.grid.setdefault((x // 8, y // 8), []).append((kind, x, y))
        if kind in FEET:
            x0, y0, x1, y1 = feet_rect(kind, x, y)
            for cx in range(int(x0 // TILE), int((x1 - 0.01) // TILE) + 1):
                for cy in range(int(y0 // TILE), int((y1 - 0.01) // TILE) + 1):
                    self.blocked.add((cx, cy))


def land_tiles(band, dmin=3):
    return [(x, y) for y in range(m.S) for x in range(m.S)
            if (x, y) in m.MAIN and m.DSEA[y][x] >= dmin and biome_of(x, y) == band]


@functools.lru_cache(maxsize=None)
def biome_of(x, y):
    """Bioma do tile: as faixas por Y do `mapa-ilha.md` com a divisa recortada por ruido, para virar formacao
    natural e nao um corte reto. A divisa soma a onda longa do `mapa_sim` (+-7 tiles) e quatro ondas de 28, 16, 9 e 5 tiles
    (+-8, 6, 4 e 2,5), que fazem recortes e linguas de bioma de 8 a 12 tiles. Tudo por semente.
    Regra de transicao do `terreno.png`: Mata-baixa nao encosta na praia (so onde ha ao menos 1 tile de Campina
    entre as duas), entao a Mata so existe a 5 ou mais tiles do mar e a faixa de ate 4 vira Campina (sobra Campina entre a Mata e a praia, mesmo na diagonal)."""
    shift = 7.0 * m.ruido(x, y, m.SEED + 31)
    for k, (wave, amp) in enumerate(((28.0, 8.0), (16.0, 6.0), (9.0, 4.0), (5.0, 2.5))):
        shift += amp * (2 * m._vn(x / wave + 0.37 * k, y / wave + 0.61 * k, m.SEED + 53 + 7 * k) - 1)
    band = m.faixa(min(m.S - 1, max(0, int(round(y + shift)))))
    if band == "M" and m.DSEA[y][x] < 5:
        return "C"
    return band


def build_terrain():
    rows = []
    for y in range(m.S):
        row = []
        for x in range(m.S):
            if m.LAND[y][x]:
                row.append("2" if m.DSEA[y][x] <= 2 else str(BIOME_CODE[biome_of(x, y)]))
            else:
                row.append("1" if m.DLAND[y][x] <= 3 else ("6" if m.DLAND[y][x] <= 5 else "0"))
        rows.append("".join(row))
    return rows


def trail_points(start, far):
    """Caminho do inicio ate a ponta mais distante (retrocedendo pelas distancias do dijkstra)."""
    d = m.dijkstra(start)
    path, cur = [far], far
    while cur != start:
        best = None
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                nxt = (cur[0] + dx, cur[1] + dy)
                if nxt in d and (best is None or d[nxt] < d[best]):
                    best = nxt
        if best is None or d[best] >= d[cur]:
            break
        cur = best
        path.append(cur)
    path.reverse()
    return path


def place_everything(site, rng):
    placer = Placer(rng)
    start = site["inicio"]
    esc, _ = m.contagens()

    def far_from_start(x, y, r=START_CLEAR):
        return math.hypot(x - start[0], y - start[1]) >= r

    def grow(kind, band, count, cluster, spread, bucket, spacing_key):
        pool = land_tiles(band)
        placed = 0
        guard = 0
        while placed < count and guard < count * 400:
            guard += 1
            cx, cy = rng.choice(pool)
            n = min(count - placed, rng.randint(*cluster))
            for _ in range(n):
                for _try in range(30):
                    x = cx + rng.randint(-spread, spread)
                    y = cy + rng.randint(-spread, spread)
                    if not (0 <= x < m.S and 0 <= y < m.S) or (x, y) not in m.MAIN or m.DSEA[y][x] < 3:
                        continue
                    if biome_of(x, y) != band or not far_from_start(x, y) or not placer.free(kind, x, y, SPACING[spacing_key]):
                        continue
                    placer.add(kind, x, y)
                    bucket.append((x, y))
                    placed += 1
                    break
        return placed

    nodes = {"tree": [], "bush_baga": [], "bush_sono": [], "rock": [], "loose_stone": [], "iron_seam": []}
    # Arvores: TODAS coletaveis (liberam area para construir). O total por bioma e o de antes (as coletaveis mais as de
    # cenario de entao); a variedade visual e das variantes da propria arvore (`ResourceNodeView`). Bosquetes de 2 a 4.
    for band in ("C", "M", "P"):
        base = round({"C": 22, "M": 36, "P": 8}[band] * esc[band])
        grow("tree", band, base * (3 if band == "P" else 4), (2, 4), 4, nodes["tree"], "tree")
    # Arbustos: baga na Campina e Mata, sono (Cochilo) so na Mata.
    for band, n128 in (("C", 14), ("M", 8)):
        grow("bush", band, round(n128 * esc[band]), (1, 3), 3, nodes["bush_baga"], "bush")
    grow("bush", "M", round(10 * esc["M"]), (1, 3), 3, nodes["bush_sono"], "bush")
    # Rochas de pedra (so Picareta): Pedreira concentra.
    for band, n128 in (("C", 6), ("M", 8), ("P", 30)):
        grow("rock", band, round(n128 * esc[band]), (1, 3), 2, nodes["rock"], "rock")
    # Filoes de ferro (M4: o jogo nao os instancia na v0.2): flanco leste da Pedreira.
    east = [(x, y) for (x, y) in land_tiles("P") if x >= 150]
    tries = 0
    while len(nodes["iron_seam"]) < round(8 * esc["P"]) and tries < 5000:
        tries += 1
        x, y = rng.choice(east)
        if placer.free("rock", x, y, SPACING["rock"]):
            placer.add("rock", x, y)
            nodes["iron_seam"].append((x, y))
    # Formacoes rochosas aleatorias (obstaculos que moldam a visao e a fuga).
    forms = []
    for band, n in (("P", 30), ("M", 12), ("C", 8)):
        pool = land_tiles(band, 4)
        done, guard = 0, 0
        while done < n and guard < 4000:
            guard += 1
            x, y = rng.choice(pool)
            kind = rng.choice(["formation_a", "formation_b", "formation_c"])
            if far_from_start(x, y, 12) and placer.free("formation", x, y, SPACING["formation"]):
                placer.add(kind, x, y)
                forms.append((kind, x, y))
                done += 1
    # Pedras avulsas: 10 no nucleo (volta em 300 s) e na trilha ate a ponta (volta em 600 s).
    far = max(m.dijkstra(start).items(), key=lambda kv: kv[1])[0]
    loose_core, loose_trail = [], []
    core = [(x, y) for y in range(m.S) for x in range(m.S) if (x, y) in m.MAIN and m.DSEA[y][x] >= 3
            and 5 <= math.hypot(x - start[0], y - start[1]) <= 16 and placer.free("rock", x, y, 2.0)]
    rng.shuffle(core)
    for x, y in core:
        if len(loose_core) == 10:
            break
        if all(math.hypot(x - a, y - b) >= 3 for a, b in loose_core):
            loose_core.append((x, y))
            placer.add("loose", x, y)
    path = trail_points(start, far)
    wanted = [path[i] for i in range(24, len(path), 24)]
    entry = [p for p in path if biome_of(p[0], p[1]) == "P"]
    wanted += [entry[i] for i in (0, 3, 6, 9)] if len(entry) > 9 else entry[:4]
    for (px, py) in wanted:
        for r in range(0, 7):
            spots = [(px + dx, py + dy) for dx in range(-r, r + 1) for dy in range(-r, r + 1)
                     if (px + dx, py + dy) in m.MAIN and m.DSEA[py + dy][px + dx] >= 3
                     and placer.free("rock", px + dx, py + dy, 2.0)]
            if spots:
                x, y = spots[0]
                loose_trail.append((x, y))
                placer.add("loose", x, y)
                break
    extra = 12
    while len(loose_trail) < 14 and extra < len(path):   # completa as 14 da trilha se algum ponto nao coube
        px, py = path[extra]
        extra += 24
        spots = [(px + dx, py + dy) for dx in range(-3, 4) for dy in range(-3, 4)
                 if (px + dx, py + dy) in m.MAIN and m.DSEA[py + dy][px + dx] >= 3 and placer.free("rock", px + dx, py + dy, 2.0)]
        if spots:
            loose_trail.append(spots[0])
            placer.add("loose", *spots[0])
    nodes["loose_stone"] = loose_core + loose_trail
    return placer, nodes, forms, loose_core, loose_trail, path


def landmark_formations(site, placer, rng):
    """Marcos de pedra (mapa-ilha.md 4): arco, pilar, portal (vao de 4) e o rochedo do cabo."""
    out = []
    ax, ay = site["arco"]
    out.append(("formation_b", ax, ay, "arco"))
    lx, ly = site["aviso"]
    out.append(("formation_a", lx, ly, "aviso"))
    # Cabo-Salgado: terra firme mais ao norte.
    cabo = min(((x, y) for (x, y) in m.MAIN if m.DSEA[y][x] >= 3), key=lambda p: (p[1], p[0]))
    out.append(("formation_a", cabo[0], cabo[1], "cabo"))
    # Portal-de-Pedra: aglomerado irregular de formacoes naturais no pescoco sul (sem linha, sem muro): pecas de
    # tamanhos variados, deslocadas em x, com falhas, e uma passagem de 4 tiles perto do meio.
    xp, ymid = site["portal"]
    ys = [y for y in range(int(0.625 * m.S), m.S) if (xp, y) in m.MAIN and m.DSEA[y][xp] >= 1]
    gap0 = ymid - 2 + rng.choice((-1, 0, 1))
    gap1 = gap0 + 4
    taken = {(ix, iy) for (_, ix, iy) in placer.items} | {(mx, my) for (_, mx, my, _) in out}  # uma celula por item
    recent = []
    skipped = False
    y = ys[0]
    while y <= ys[-1]:
        if gap0 <= y < gap1:
            y = gap1
            continue
        if not skipped and rng.random() < 0.22:
            skipped = True
            y += 1
            continue
        skipped = False
        dx = rng.choice([d for d in (-3, -2, -1, 0, 1, 2, 3) if d not in recent[-2:]])
        recent.append(dx)
        kind = rng.choices(["formation_c", "formation_b", "formation_a"], weights=[5, 2, 3])[0]
        if (xp + dx, y) in m.MAIN and (xp + dx, y) not in taken:
            out.append((kind, xp + dx, y, "portal"))
        y += rng.choice((2, 2, 3))
    return out, cabo


def reachable_ratio(placer, start):
    walk = lambda x, y: 0 <= x < m.S and 0 <= y < m.S and m.caminhavel(x, y) and (x, y) not in placer.blocked
    seen = {start}
    q = deque([start])
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (x + dx, y + dy)
            if n not in seen and walk(*n):
                seen.add(n)
                q.append(n)
    total = sum(1 for (x, y) in m.MAIN if m.LAND[y][x] and m.DSEA[y][x] >= 2 and (x, y) not in placer.blocked)
    ok = sum(1 for (x, y) in seen if (x, y) in m.MAIN and m.DSEA[y][x] >= 2)
    return ok / total, seen


def build_slots():
    """Vagas sem id, na ordem da tabela. O id sai de `assign_slot_ids`."""
    return [{"species": sp, "region": reg, "size": size, "size_min": lo, "size_max": hi}
            for sp, reg, lo, hi, sizes in SLOT_TABLE for size in sizes]


def region_masks(rows, blocked):
    """Mascara por regiao: runs [y, x0, x1] (x1 inclusivo) dos tiles cujo terreno esta em `terrains` e que nao
    estao em `blocked`. Ordem fixa: y crescente, x crescente."""
    out = {}
    for name, terrains in REGIONS.items():
        codes = {str(t) for t in terrains}
        runs = []
        for y, row in enumerate(rows):
            x = 0
            while x < len(row):
                if row[x] in codes and (x, y) not in blocked:
                    x0 = x
                    while x + 1 < len(row) and row[x + 1] in codes and (x + 1, y) not in blocked:
                        x += 1
                    runs.append([y, x0, x])
                x += 1
        out[name] = {"terrains": list(terrains), "runs": runs}
    return out


def assign_slot_ids(slots, previous_slots, counter, report):
    """Poe `id` nas vagas. Por (especie, regiao), as anteriores em ordem de id herdam o id; excedente e aposentado;
    falta ganha id novo (contador `counter["g"]`, nunca volta). Devolve as vagas novas com `id` em primeiro."""
    def num(slot):
        return int(slot["id"][1:])
    olds = {}
    for o in sorted(previous_slots, key=num):
        olds.setdefault((o["species"], o["region"]), []).append(o["id"])
    out = []
    for slot in slots:
        queue = olds.get((slot["species"], slot["region"]), [])
        if queue:
            sid = queue.pop(0)
            report["kept"].append(sid)
        else:
            counter["g"] += 1
            sid = "g%d" % counter["g"]
            report["new"].append(sid)
        out.append({"id": sid, **slot})
    report["retired"] += [i for q in olds.values() for i in q]
    return out


def match_ids(old_points, new_points, old_ids):
    """Casa pontos novos com os anteriores do mesmo tipo (raio ID_RADIUS), do mais perto ao mais longe,
    sem repetir. Devolve lista paralela a `new_points`: id herdado ou None."""
    pairs = []
    for i, (nx, ny) in enumerate(new_points):
        for j, (ox, oy) in enumerate(old_points):
            d = math.hypot(nx - ox, ny - oy)
            if d <= ID_RADIUS:
                pairs.append((d, i, j))
    pairs.sort()
    out = [None] * len(new_points)
    used = set()
    for _, i, j in pairs:
        if out[i] is None and j not in used:
            out[i] = old_ids[j]
            used.add(j)
    return out


def assign_ids(data, previous, first_generation):
    """Poe `node_ids` e `id_counter` em `data`. Devolve o relatorio {mantidos, novos, aposentados}."""
    report = {"kept": [], "new": [], "retired": []}
    if first_generation:
        node_ids, nc = {}, 0
        for kind in sorted(data["nodes"]):
            node_ids[kind] = ["n%d" % (nc + i + 1) for i in range(len(data["nodes"][kind]))]
            nc += len(data["nodes"][kind])
        report["new"] = [i for v in list(node_ids.values()) for i in v]
        counter = {"w": 0, "n": nc, "g": 0}
        if "spawn_slots" in data:
            data["spawn_slots"] = assign_slot_ids(data["spawn_slots"], [], counter, report)
        data["node_ids"], data["id_counter"] = node_ids, counter
        return report
    counter = dict(previous["id_counter"])
    counter.setdefault("g", 0)
    for group, prefix, key in (("nodes", "n", "node_ids"),):
        data[key] = {}
        for kind, pts in data[group].items():
            old = previous[group].get(kind, [])
            old_ids = previous[key].get(kind, [])
            got = match_ids(old, pts, old_ids)
            for i, v in enumerate(got):
                if v is None:
                    counter[prefix] += 1
                    got[i] = "%s%d" % (prefix, counter[prefix])
                    report["new"].append(got[i])
                else:
                    report["kept"].append(v)
            data[key][kind] = got
    still = set(report["kept"])
    old_all = [i for k in ("node_ids",) for v in previous[k].values() for i in v]
    report["retired"] = [i for i in old_all if i not in still]
    if "spawn_slots" in data:
        data["spawn_slots"] = assign_slot_ids(data["spawn_slots"], previous.get("spawn_slots", []), counter, report)
    data["id_counter"] = counter
    return report


def canonical(data):
    """Copia do conteudo sem `revision` e `content_hash`, com listas de pontos ordenadas (id, x, y) para a
    ordem nao mexer no hash. Os terrenos (`rows`) mantem a ordem: ela e o conteudo."""
    c = {k: v for k, v in data.items() if k not in ("revision", "content_hash")}
    for group, key in (("nodes", "node_ids"),):
        merged = {}
        for kind, pts in data[group].items():
            merged[kind] = sorted([i, p[0], p[1]] for i, p in zip(data[key][kind], pts))
        c[group] = merged
        del c[key]
    if "spawn_slots" in data:
        c["spawn_slots"] = sorted(data["spawn_slots"], key=lambda sl: int(sl["id"][1:]))
    if "spawn_regions" in data:
        c["spawn_regions"] = {n: {"terrains": sorted(r["terrains"]), "runs": sorted(r["runs"])}
                              for n, r in data["spawn_regions"].items()}
    c["portal_pieces"] = sorted(data["portal_pieces"])
    c["scenery"] = {k: sorted(v) for k, v in data["scenery"].items()}
    return c


def content_hash(data):
    text = json.dumps(canonical(data), sort_keys=True, ensure_ascii=False, separators=(",", ":"))
    return hashlib.sha256(text.encode("utf-8")).hexdigest()[:16]


def load_previous(path):
    """Arquivo anterior com ids, ou None se nao existe / ainda nao tem ids."""
    if not os.path.exists(path):
        return None
    with open(path, encoding="utf-8") as f:
        prev = json.load(f)
    return prev if all(k in prev for k in ("node_ids", "id_counter")) else None


def export():
    m.preparar(256)
    rng = random.Random(m.SEED * 7919 + 13)
    site = m.sitios()
    start = site["inicio"]
    placer, nodes, forms, loose_core, loose_trail, path = place_everything(site, rng)
    marks, cabo = landmark_formations(site, placer, rng)
    for kind, x, y, _ in marks:
        placer.add(kind, x, y)
    ratio, seen = reachable_ratio(placer, start)
    scenery = {"formation_a": [], "formation_b": [], "formation_c": []}
    for kind, x, y in forms:
        scenery[kind].append((x, y))
    for kind, x, y, _ in marks:
        scenery[kind].append((x, y))
    for k in ("formation_a", "formation_b", "formation_c"):
        scenery[k] = sorted(set(scenery[k]))
    rows = build_terrain()
    data = {
        "format": FORMAT,
        "revision": REVISION,
        "id": "lunata",
        "name": "Lunata",
        "source": "documentacao/design/mapa_sim.py (forma) e documentacao/design/mapa_export.py (nos e cenario); semente %d" % m.SEED,
        "tile": TILE,
        "size": m.S,
        "seed": m.SEED,
        "terrains": TERRAINS,
        "rows": rows,
        "start": list(start),
        "landmarks": {
            "arco_da_enseada": list(site["arco"]),
            "pedra_do_aviso": list(site["aviso"]),
            "portal_de_pedra": list(site["portal"]),
            "cabo_salgado": list(cabo),
            "paquicefalo_tutorial": list(site["paq_tutorial"]),
            "paquicefalo_limiar": list(site["paq_limiar"]),
        },
        "portal_pieces": [[k, x, y] for (k, x, y, tag) in marks if tag == "portal"],
        "dens": {k: list(v) for k, v in sorted(site["tocas"].items())},
        "nodes": {k: [list(p) for p in sorted(v)] for k, v in nodes.items()},
        "loose_stone_respawn": {"core": 300, "trail": 600, "core_count": len(loose_core)},
        "scenery": {k: [list(p) for p in v] for k, v in scenery.items()},
        "spawn_slots": build_slots(),
        "spawn_regions": region_masks(rows, placer.blocked),
    }
    return data, ratio


def dump(data):
    # Linhas do terreno uma por linha; o resto compacto. Estavel: chaves na ordem de insercao.
    head = {k: v for k, v in data.items() if k != "rows"}
    text = json.dumps(head, ensure_ascii=False, separators=(",", ":"))
    rows = ",\n".join(json.dumps(r) for r in data["rows"])
    return text[:-1] + ',"rows":[\n' + rows + "\n]}\n"


def main():
    data, ratio = export()
    path = os.path.normpath(OUT)
    previous = load_previous(path)
    first = "--primeira-geracao" in sys.argv
    if previous is None and not first:
        sys.exit("recusado: sem arquivo anterior com ids em %s. Reexportar do zero emitiria ids novos para "
                 "tudo; se e mesmo a primeira geracao, use --primeira-geracao." % path)
    if previous is not None and first:
        sys.exit("recusado: ja existe arquivo anterior com ids; --primeira-geracao descartaria todos eles.")
    report = assign_ids(data, previous, previous is None)
    data["content_hash"] = content_hash(data)
    text = dump(data)
    if "--check" in sys.argv:
        with open(path, encoding="utf-8") as f:
            same = f.read() == text
        print("lunata.json %s" % ("igual ao que sai do script" if same else "DIFERE do script"))
        sys.exit(0 if same else 1)
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)
    n = data["nodes"]
    print("gravado %s (%d bytes)" % (path, len(text.encode())))
    print("nos:", {k: len(v) for k, v in n.items()}, "| cenario:", {k: len(v) for k, v in data["scenery"].items()},
)
    print("vagas:", len(data["spawn_slots"]), "| runs:", {k: len(v["runs"]) for k, v in data["spawn_regions"].items()})
    print("terra firme alcancavel a pe, com obstaculos: %.2f%%" % (ratio * 100))
    print("ids: %d mantidos, %d novos, %d aposentados | content_hash %s" % (
        len(report["kept"]), len(report["new"]), len(report["retired"]), data["content_hash"]))
    for label, key in (("novos", "new"), ("aposentados", "retired")):
        if 0 < len(report[key]) <= 50:
            print("  %s: %s" % (label, ", ".join(report[key])))


if __name__ == "__main__":
    main()
