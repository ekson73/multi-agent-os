#!/usr/bin/env python3
"""Tests for project_roadmap.py — lock the graph invariants.

Run: python3 skills/roadmap-tree-projector/scripts/test_project_roadmap.py
Exit 0 = all pass, non-zero = a failure (CI-gateable).
Pure stdlib (unittest) — no third-party test runner needed.
"""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import project_roadmap as pr  # noqa: E402


def _doc(nodes, edges):
    return {"version": 1, "nodes": nodes, "edges": edges}


class TestValidate(unittest.TestCase):
    def test_clean_doc_has_no_errors(self):
        doc = _doc(
            [{"id": "A", "kind": "goal", "title": "a"}, {"id": "B", "kind": "item", "title": "b"}],
            [{"from": "B", "to": "A", "type": "depends-on"}],
        )
        self.assertEqual(pr.validate(doc), [])

    def test_wrong_version_flagged(self):
        doc = {"version": 99, "nodes": [], "edges": []}
        self.assertTrue(any("version" in e for e in pr.validate(doc)))

    def test_duplicate_id_flagged(self):
        doc = _doc(
            [{"id": "A", "kind": "goal", "title": "a"}, {"id": "A", "kind": "item", "title": "a2"}], []
        )
        self.assertTrue(any("duplicate" in e for e in pr.validate(doc)))

    def test_unknown_kind_flagged(self):
        doc = _doc([{"id": "A", "kind": "wizard", "title": "a"}], [])
        self.assertTrue(any("unknown kind" in e for e in pr.validate(doc)))

    def test_edge_to_unknown_node_flagged(self):
        doc = _doc(
            [{"id": "A", "kind": "goal", "title": "a"}],
            [{"from": "A", "to": "GHOST", "type": "depends-on"}],
        )
        self.assertTrue(any("unknown node" in e for e in pr.validate(doc)))


class TestCycle(unittest.TestCase):
    def test_acyclic_returns_none(self):
        doc = _doc(
            [{"id": "A", "kind": "goal", "title": "a"}, {"id": "B", "kind": "item", "title": "b"}],
            [{"from": "B", "to": "A", "type": "depends-on"}],
        )
        self.assertIsNone(pr.detect_cycle(doc))

    def test_cycle_detected(self):
        doc = _doc(
            [{"id": "A", "kind": "goal", "title": "a"}, {"id": "B", "kind": "item", "title": "b"}],
            [
                {"from": "A", "to": "B", "type": "depends-on"},
                {"from": "B", "to": "A", "type": "depends-on"},
            ],
        )
        self.assertIsNotNone(pr.detect_cycle(doc))

    def test_blocks_normalized_to_depends_on(self):
        # A blocks B  ==  B depends-on A ; combined with B depends-on A directly
        # must NOT create a false cycle, and topo must place A before B.
        doc = _doc(
            [{"id": "A", "kind": "goal", "title": "a"}, {"id": "B", "kind": "item", "title": "b"}],
            [{"from": "A", "to": "B", "type": "blocks"}],
        )
        self.assertIsNone(pr.detect_cycle(doc))
        order = pr.topo_order(doc)
        self.assertLess(order.index("A"), order.index("B"))


class TestTopo(unittest.TestCase):
    def test_dependency_respected(self):
        doc = _doc(
            [
                {"id": "R", "kind": "dor", "title": "ready"},
                {"id": "T", "kind": "item", "title": "task"},
                {"id": "D", "kind": "dod", "title": "done"},
            ],
            [
                {"from": "T", "to": "R", "type": "depends-on"},
                {"from": "D", "to": "T", "type": "depends-on"},
            ],
        )
        order = pr.topo_order(doc)
        self.assertLess(order.index("R"), order.index("T"))
        self.assertLess(order.index("T"), order.index("D"))

    def test_realizes_is_not_ordering_constraint(self):
        # realizes should not force topo order (it is structural, not gating)
        doc = _doc(
            [{"id": "A", "kind": "goal", "title": "a"}, {"id": "B", "kind": "objective", "title": "b"}],
            [{"from": "B", "to": "A", "type": "realizes"}],
        )
        self.assertIsNone(pr.detect_cycle(doc))


class TestStatusFile(unittest.TestCase):
    def test_parse_ignores_comments_and_blanks(self):
        import tempfile

        with tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False) as f:
            f.write("# comment\n\nA=green\n B = red \n")
            name = f.name
        try:
            got = pr.load_status_file(name)
            self.assertEqual(got, {"A": "green", "B": "red"})
        finally:
            os.unlink(name)


if __name__ == "__main__":
    unittest.main(verbosity=2)
