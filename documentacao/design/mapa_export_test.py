#!/usr/bin/env python3
"""Testes dos ids estaveis e do hash de conteudo do exportador (ADR-007). So biblioteca padrao.
Rodar: python3 documentacao/design/mapa_export_test.py"""
import copy
import json
import math
import os
import random
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mapa_export as ex  # noqa: E402


def base_data():
    return {
        "landmarks": {"paquicefalo_tutorial": [1, 1]},
        "portal_pieces": [["formation_a", 5, 5], ["formation_b", 2, 2]],
        "scenery": {"formation_a": [[9, 9], [3, 3]]},
        "rows": [[0, 1], [1, 0]],
        "nodes": {"tree": [[10, 10], [20, 20], [30, 30]], "rock": [[40, 40]]},
    }


def first():
    data = base_data()
    ex.assign_ids(data, None, True)
    return data


def regen(previous, mutate):
    data = base_data()
    mutate(data)
    report = ex.assign_ids(data, previous, False)
    return data, report


class IdsEstaveis(unittest.TestCase):
    def test_primeira_geracao_ids_unicos_sem_spawn_ids(self):
        d = first()
        todos = [i for v in d["node_ids"].values() for i in v]
        self.assertEqual(len(todos), len(set(todos)))
        self.assertEqual(d["node_ids"]["rock"], ["n1"])
        self.assertNotIn("spawn_ids", d)
        self.assertEqual(d["id_counter"]["w"], 0)  # historico, sem uso

    def test_reexportar_igual_mantem_tudo(self):
        prev = first()
        d, rep = regen(prev, lambda x: None)
        self.assertEqual(d["node_ids"], prev["node_ids"])
        self.assertEqual((rep["new"], rep["retired"]), ([], []))

    def test_mexer_em_um_ponto_mantem_os_outros(self):
        prev = first()
        d, rep = regen(prev, lambda x: x["nodes"]["tree"].pop(1))
        self.assertEqual(d["node_ids"]["tree"], [prev["node_ids"]["tree"][0], prev["node_ids"]["tree"][2]])
        self.assertEqual(rep["retired"], [prev["node_ids"]["tree"][1]])
        self.assertEqual(d["node_ids"]["rock"], prev["node_ids"]["rock"])

    def test_movido_1_tile_mantem_e_3_tiles_vira_novo(self):
        prev = first()
        d1, _ = regen(prev, lambda x: x["nodes"]["tree"].__setitem__(0, [11, 10]))
        self.assertEqual(d1["node_ids"]["tree"][0], prev["node_ids"]["tree"][0])
        d3, rep = regen(prev, lambda x: x["nodes"]["tree"].__setitem__(0, [13, 10]))
        self.assertNotEqual(d3["node_ids"]["tree"][0], prev["node_ids"]["tree"][0])
        self.assertIn(prev["node_ids"]["tree"][0], rep["retired"])

    def test_id_aposentado_nunca_volta(self):
        prev = first()
        d2, _ = regen(prev, lambda x: x["nodes"]["tree"].pop())  # aposenta o ultimo
        retirado = prev["node_ids"]["tree"][2]
        d3, _ = regen(d2, lambda x: None)
        d3b, _ = regen(d2, lambda x: x["nodes"]["tree"].append([30, 30]))  # ponto novo no mesmo lugar
        self.assertNotIn(retirado, d3b["node_ids"]["tree"])
        self.assertNotIn(retirado, d3["node_ids"]["tree"])

    def test_tipo_diferente_nao_herda(self):
        prev = first()
        d, _ = regen(prev, lambda x: (x["nodes"]["rock"].clear(), x["nodes"]["tree"].append([40, 40])))
        self.assertNotIn(prev["node_ids"]["rock"][0], d["node_ids"]["tree"])


class HashDeConteudo(unittest.TestCase):
    def setUp(self):
        self.d = first()

    def test_muda_quando_conteudo_muda(self):
        h = ex.content_hash(self.d)
        for mutate in (lambda x: x["nodes"]["tree"][0].__setitem__(0, 99),
                       lambda x: x["rows"][0].__setitem__(0, 5),
                       lambda x: x["node_ids"]["rock"].__setitem__(0, "n999")):
            d = copy.deepcopy(self.d)
            mutate(d)
            self.assertNotEqual(h, ex.content_hash(d))

    def test_nao_muda_so_com_a_ordem(self):
        h = ex.content_hash(self.d)
        d = copy.deepcopy(self.d)
        for g, k in (("nodes", "node_ids"),):
            for kind in d[g]:
                d[g][kind].reverse()
                d[k][kind].reverse()
        d["portal_pieces"].reverse()
        d["scenery"]["formation_a"].reverse()
        self.assertEqual(h, ex.content_hash(d))

    def test_ignora_revision_e_o_proprio_hash(self):
        h = ex.content_hash(self.d)
        self.d["revision"] = 7
        self.d["content_hash"] = "x"
        self.assertEqual(h, ex.content_hash(self.d))


def with_slots(data):
    data["spawn_slots"] = ex.build_slots()
    return data


class VagasDeBando(unittest.TestCase):
    def prev(self):
        d = with_slots(base_data())
        ex.assign_ids(d, None, True)
        return d

    def regen(self, previous, mutate=lambda s: None):
        d = with_slots(base_data())
        mutate(d["spawn_slots"])
        return d, ex.assign_ids(d, previous, False)

    def test_totais_por_especie(self):
        contagem = {}
        for s in self.prev()["spawn_slots"]:
            contagem[s["species"]] = contagem.get(s["species"], 0) + 1
        self.assertEqual(contagem, {"dodo": 7, "paquicefalo": 20, "utahraptor": 6, "triceratops": 4})

    def test_ids_de_vaga_estaveis_ao_reexportar(self):
        prev = self.prev()
        d, rep = self.regen(prev)
        self.assertEqual(d["spawn_slots"], prev["spawn_slots"])
        self.assertEqual((rep["new"], rep["retired"]), ([], []))
        self.assertEqual(d["id_counter"]["g"], 37)

    def test_tamanho_diferente_mantem_id(self):
        prev = self.prev()
        d, _ = self.regen(prev, lambda sl: sl[0].__setitem__("size", 4))
        self.assertEqual([s["id"] for s in d["spawn_slots"]], [s["id"] for s in prev["spawn_slots"]])

    def test_id_aposentado_nao_volta(self):
        prev = self.prev()
        retirado = prev["spawn_slots"][-1]["id"]
        d2, rep = self.regen(prev, lambda sl: sl.pop())
        self.assertEqual(rep["retired"], [retirado])
        d3, _ = self.regen(d2)  # vaga de volta na tabela: ganha id novo, nao o antigo
        self.assertNotIn(retirado, [s["id"] for s in d3["spawn_slots"]])
        self.assertEqual(d3["spawn_slots"][-1]["id"], "g38")

    def test_hash_cobre_vagas(self):
        d = self.prev()
        h = ex.content_hash(d)
        d["spawn_slots"][0]["size"] = 4
        self.assertNotEqual(h, ex.content_hash(d))


ROWS = ["0233344", "0553345", "0000000"]


class MascaraDeRegiao(unittest.TestCase):
    def test_so_tiles_do_bioma_certo_e_sem_bloqueados(self):
        masks = ex.region_masks(ROWS, {(4, 0)})
        tiles = lambda name: {(x, y) for y, a, b in masks[name]["runs"] for x in range(a, b + 1)}
        self.assertEqual(tiles("r_campina"), {(2, 0), (3, 0), (3, 1), (4, 1)})
        self.assertEqual(tiles("r_mata"), {(5, 0), (6, 0), (5, 1)})
        self.assertEqual(tiles("r_pedreira"), {(1, 1), (2, 1), (6, 1)})
        self.assertEqual(tiles("r_campina_mata"), tiles("r_campina") | tiles("r_mata"))

    def test_mascara_muda_o_hash(self):
        d = first()
        d["spawn_regions"] = ex.region_masks(ROWS, set())
        h = ex.content_hash(d)
        d["spawn_regions"] = ex.region_masks(ROWS, {(3, 0)})
        self.assertNotEqual(h, ex.content_hash(d))

    def test_ordem_das_runs_nao_muda_o_hash(self):
        d = first()
        d["spawn_regions"] = ex.region_masks(ROWS, set())
        h = ex.content_hash(d)
        for r in d["spawn_regions"].values():
            r["runs"].reverse()
        self.assertEqual(h, ex.content_hash(d))


LUNATA = ex.os.path.normpath(ex.OUT)
SPACING_BY_SPECIES = {"dodo": 16, "paquicefalo": 24, "utahraptor": 20, "triceratops": 30}
GLOBAL_SPACING, START_CLEARANCE = 16, 12
SPECIES_ORDER = ["utahraptor", "paquicefalo", "triceratops", "dodo"]  # a ordem do jogo: tocas primeiro, depois a tabela de vagas


def region_tiles(region):
    return [(x, y) for y, x0, x1 in region["runs"] for x in range(x0, x1 + 1)]


def lay_out(world, seed):
    """Amostragem simples: por vaga, tiles da mascara em ordem aleatoria; fica com o primeiro que respeita a
    distancia de todo centro ja posto, do inicio e do tutorial. Devolve vagas sem lugar."""
    rng = random.Random(seed)
    placed = [(tuple(world["landmarks"]["paquicefalo_tutorial"]), 0)]
    masks = {n: region_tiles(r) for n, r in world["spawn_regions"].items()}
    start = tuple(world["start"])
    failed = []
    order = sorted(world["spawn_slots"], key=lambda s: (SPECIES_ORDER.index(s["species"]), int(s["id"][1:])))
    for slot in order:
        if "den" in slot:  # o bando nasce na toca (E3): centro fixo, sem sorteio
            placed.append((tuple(world["dens"][slot["den"]]), slot["species"]))
            continue
        need = max(GLOBAL_SPACING, SPACING_BY_SPECIES[slot["species"]])
        pool = list(masks[slot["region"]])
        rng.shuffle(pool)
        for (x, y) in pool:
            if math.hypot(x - start[0], y - start[1]) < START_CLEARANCE:
                continue
            if all(math.hypot(x - px, y - py) >= max(GLOBAL_SPACING, need if sp == slot["species"] else 0)
                   for (px, py), sp in ((c, s) for c, s in placed)):
                placed.append(((x, y), slot["species"]))
                break
        else:
            failed.append(slot["id"])
    return failed


class MapaGravado(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with open(LUNATA, encoding="utf-8") as f:
            cls.world = json.load(f)

    def test_hash_gravado_confere(self):
        self.assertEqual(self.world["content_hash"], ex.content_hash(self.world))

    def test_mascara_dodo_so_mata(self):
        slot = next(s for s in self.world["spawn_slots"] if s["species"] == "dodo")
        region = self.world["spawn_regions"][slot["region"]]
        self.assertEqual(region["terrains"], [4])
        codes = {self.world["rows"][y][x] for x, y in region_tiles(region)}
        self.assertEqual(codes, {"4"})  # E13: so Mata-baixa (nada de campina, pedreira nem praia)
        total = sum(s["size"] for s in self.world["spawn_slots"] if s["species"] == "dodo")
        self.assertEqual(total, 140)

    def test_mascaras_respeitam_terrenos_e_bloqueio(self):
        for name, region in self.world["spawn_regions"].items():
            allowed = {str(t) for t in region["terrains"]}
            for x, y in region_tiles(region):
                self.assertIn(self.world["rows"][y][x], allowed, name)

    def test_vagas_apontam_para_regioes_existentes(self):
        for s in self.world["spawn_slots"]:
            self.assertIn(s["region"], self.world["spawn_regions"])
            self.assertLessEqual(s["size_min"], s["size"])
            self.assertLessEqual(s["size"], s["size_max"])

    def test_vagas_de_utahraptor_tem_toca_unica_em_terreno_de_mata(self):
        dens = [s["den"] for s in self.world["spawn_slots"] if s["species"] == "utahraptor"]
        self.assertEqual(dens, ["U1", "U2", "U3", "U4", "U5", "U6"])
        for den in dens:
            x, y = self.world["dens"][den]
            self.assertEqual(self.world["rows"][y][x], "4", den)  # terreno 4 (mata baixa)
        self.assertEqual(self.world["dens"]["U1"], [68, 136])  # D-E1
        self.assertEqual(self.world["dens"]["U6"], [32, 130])

    def test_viabilidade_vagas_em_100_sementes(self):
        falhas = {seed: f for seed in range(100) if (f := lay_out(self.world, seed))}
        dodos = {s["id"] for s in self.world["spawn_slots"] if s["species"] == "dodo"}
        # E13: 140 dodos na Mata-baixa nao cabem sempre (o jogo mede 3 de 100 sementes; este sorteio e mais cru). So uma vaga
        # de dodo pode faltar, nunca de outra especie, e em poucas sementes.
        fora = {seed: [i for i in f if i not in dodos] for seed, f in falhas.items()}
        self.assertEqual({k: v for k, v in fora.items() if v}, {}, "vaga de outra especie sem lugar")
        self.assertLessEqual(len(falhas), 15, "sementes com vaga de dodo sem lugar: %d de 100" % len(falhas))


if __name__ == "__main__":
    unittest.main()
