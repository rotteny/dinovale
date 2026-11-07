#!/usr/bin/env python3
"""Testes dos ids estaveis e do hash de conteudo do exportador (ADR-007). So biblioteca padrao.
Rodar: python3 docs/design/mapa_export_test.py"""
import copy
import os
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
        "spawns": {"paquicefalo": [[50, 50], [60, 60], [1, 1]], "utahraptor": [[70, 70]]},
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
    def test_primeira_geracao_ids_unicos_e_pula_tutorial(self):
        d = first()
        todos = [i for g in ("spawn_ids", "node_ids") for v in d[g].values() for i in v]
        self.assertEqual(len(todos), len(set(todos)))
        self.assertEqual(d["spawn_ids"]["paquicefalo"][:2], ["w0", "w1"])
        self.assertEqual(d["spawn_ids"]["utahraptor"][0], "w2")  # o do tutorial fica depois dos indices do jogo

    def test_reexportar_igual_mantem_tudo(self):
        prev = first()
        d, rep = regen(prev, lambda x: None)
        self.assertEqual(d["spawn_ids"], prev["spawn_ids"])
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
                       lambda x: x["spawn_ids"]["utahraptor"].__setitem__(0, "w999")):
            d = copy.deepcopy(self.d)
            mutate(d)
            self.assertNotEqual(h, ex.content_hash(d))

    def test_nao_muda_so_com_a_ordem(self):
        h = ex.content_hash(self.d)
        d = copy.deepcopy(self.d)
        for g, k in (("nodes", "node_ids"), ("spawns", "spawn_ids")):
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


if __name__ == "__main__":
    unittest.main()
