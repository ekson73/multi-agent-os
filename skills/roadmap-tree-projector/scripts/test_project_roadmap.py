#!/usr/bin/env python3
"""Tests for project_roadmap.py — lock the graph invariants.

Run: python3 skills/roadmap-tree-projector/scripts/test_project_roadmap.py
Exit 0 = all pass, non-zero = a failure (CI-gateable).
Pure stdlib (unittest) — no third-party test runner needed.
"""
import json
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


class TestParentsValidation(unittest.TestCase):
    # Finding #1 (P1 silent-wrong): a typo'd parent must be an ERROR, not a
    # silently-dropped node.
    def test_unknown_parent_flagged(self):
        doc = _doc(
            [
                {"id": "A", "kind": "goal", "title": "a"},
                {"id": "B", "kind": "item", "title": "b", "parents": ["GHOST"]},
            ],
            [],
        )
        self.assertTrue(any("parent references unknown node" in e for e in pr.validate(doc)))

    def test_valid_parent_ok(self):
        doc = _doc(
            [
                {"id": "A", "kind": "goal", "title": "a"},
                {"id": "B", "kind": "item", "title": "b", "parents": ["A"]},
            ],
            [],
        )
        self.assertEqual(pr.validate(doc), [])


class TestTitleRequired(unittest.TestCase):
    # Finding #7 (P2): a titleless node renders a blank branch.
    def test_missing_title_flagged(self):
        doc = _doc([{"id": "A", "kind": "goal"}], [])
        self.assertTrue(any("missing required 'title'" in e for e in pr.validate(doc)))


class TestEffectiveStatusInJson(unittest.TestCase):
    # Finding #2 (P1 silent-wrong): measured status must survive into --json.
    def test_effective_status_prefers_measured(self):
        node = {"id": "A", "kind": "goal", "title": "a", "status": "declared"}
        self.assertEqual(pr.effective_status(node, {"A": "green"}), "green")

    def test_effective_status_falls_back_to_declared(self):
        node = {"id": "A", "kind": "goal", "title": "a", "status": "declared"}
        self.assertEqual(pr.effective_status(node, {}), "declared")

    def test_json_branch_includes_measured_status(self):
        import io
        import tempfile
        from contextlib import redirect_stdout

        roadmap = _doc([{"id": "A", "kind": "goal", "title": "a"}], [])
        with tempfile.NamedTemporaryFile("w", suffix=".yaml", delete=False) as rf:
            import yaml

            rf.write(yaml.safe_dump(roadmap))
            rname = rf.name
        with tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False) as sf:
            sf.write("A=measured-green\n")
            sname = sf.name
        try:
            buf = io.StringIO()
            with redirect_stdout(buf):
                rc = pr.main(["--roadmap", rname, "--status-file", sname, "--json"])
            self.assertEqual(rc, 0)
            env = json.loads(buf.getvalue())
            a = next(n for n in env["nodes"] if n["id"] == "A")
            self.assertEqual(a["effective_status"], "measured-green")
        finally:
            os.unlink(rname)
            os.unlink(sname)


class TestExitCodes(unittest.TestCase):
    # Finding #3 (P1): unknown lens / bad parent must exit non-zero, not 0.
    def _write_roadmap(self, doc):
        import tempfile

        import yaml

        f = tempfile.NamedTemporaryFile("w", suffix=".yaml", delete=False)
        f.write(yaml.safe_dump(doc))
        f.close()
        return f.name

    def test_unknown_lens_exits_nonzero(self):
        name = self._write_roadmap(_doc([{"id": "A", "kind": "goal", "title": "a"}], []))
        try:
            self.assertEqual(pr.main(["--roadmap", name, "--lens", "nope"]), 1)
        finally:
            os.unlink(name)

    def test_known_lens_exits_zero(self):
        doc = _doc([{"id": "A", "kind": "goal", "title": "a"}], [])
        doc["lenses"] = {"swot": {"strengths": ["x"]}}
        name = self._write_roadmap(doc)
        try:
            self.assertEqual(pr.main(["--roadmap", name, "--lens", "swot"]), 0)
        finally:
            os.unlink(name)

    def test_bad_parent_exits_nonzero(self):
        doc = _doc(
            [{"id": "A", "kind": "goal", "title": "a", "parents": ["GHOST"]}], []
        )
        name = self._write_roadmap(doc)
        try:
            self.assertEqual(pr.main(["--roadmap", name]), 1)
        finally:
            os.unlink(name)


class TestWorldRouting(unittest.TestCase):
    # Finding #5: probe routes by ref.manager, world is only the default.
    def test_ref_manager_wins_over_world(self):
        node = {"id": "PR1", "kind": "pr", "world": "client-alpha",
                "ref": {"manager": "github", "repo": "org/x", "pr": 1}}
        self.assertEqual(pr.resolve_probe_manager(node), "github")

    def test_world_default_when_ref_has_no_manager(self):
        node = {"id": "T1", "kind": "item", "world": "client-alpha"}
        self.assertEqual(pr.resolve_probe_manager(node), "jira")

    def test_personal_world_defaults_to_linear(self):
        node = {"id": "G1", "kind": "goal", "world": "personal"}
        self.assertEqual(pr.resolve_probe_manager(node), "linear")


class TestDuplicateYamlKeys(unittest.TestCase):
    # Finding #6 (P2): PyYAML overwrites dup keys silently; we must reject.
    def test_duplicate_key_rejected(self):
        import tempfile

        f = tempfile.NamedTemporaryFile("w", suffix=".yaml", delete=False)
        f.write("version: 1\nversion: 2\nnodes: []\nedges: []\n")
        f.close()
        try:
            with self.assertRaises(SystemExit):
                pr.load_yaml(f.name)
        finally:
            os.unlink(f.name)


if __name__ == "__main__":
    unittest.main(verbosity=2)
