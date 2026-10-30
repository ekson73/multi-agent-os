#!/usr/bin/env python3
"""Scope check for the transcript-corrector PII gate.

Uses synthetic sentinels only. Does not embed a removed name, a personal
address, or a CPF literal.
"""

from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
CHECK_PATH = REPO / "skills" / "transcript-corrector" / "scripts" / "check-pii-scope.py"
LINTER_PATH = REPO / "skills" / "pii-masking" / "linter_pii.py"
DENYLIST = REPO / "skills" / "transcript-corrector" / "ci" / "removed-name-denylist.json"
SKILL = REPO / "skills" / "transcript-corrector"


def _load(path: Path, name: str):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


class TranscriptCorrectorPiiScopeTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.check = _load(CHECK_PATH, "check_pii_scope")
        cls.linter = _load(LINTER_PATH, "linter_pii")

    def test_denylist_is_hashes_only(self) -> None:
        data = json.loads(DENYLIST.read_text(encoding="utf-8"))
        self.assertEqual(data["algorithm"], "sha256")
        self.assertRegex(data["salt"], r"^[0-9a-f]{32,128}$")
        self.assertGreaterEqual(len(data["hashes"]), 1)
        blob = DENYLIST.read_text(encoding="utf-8").lower()
        self.assertNotIn("@", blob)
        for item in data["hashes"]:
            self.assertRegex(item, r"^[0-9a-f]{64}$")
        # The salt and hashes are the only material; no whitespace-separated word
        # longer than the hex alphabet should appear as a JSON string value.
        for value in data["hashes"] + [data["salt"]]:
            self.assertTrue(set(value) <= set("0123456789abcdef"))

    def test_synthetic_name_hits_without_echoing_the_token(self) -> None:
        sentinel = "Qxpseudonym"
        salt = "ab" * 16
        denylist = {"algorithm": "sha256", "salt": salt, "hashes": self.check.seal([sentinel], salt)}
        text = f"Notes mention {sentinel} in the roster.\n"
        hits = self.check.name_hit_lines(text, salt, set(denylist["hashes"]))
        self.assertEqual(hits, [1])
        rendered = json.dumps(denylist)
        self.assertNotIn(sentinel, rendered)
        self.assertNotIn(sentinel.casefold(), rendered)

    def test_pseudonym_labels_are_not_denied(self) -> None:
        salt, hashes = self.check.load_denylist(DENYLIST)
        sample = "Invitees: P1 P2 P3 P4 P5 P6. Mishearing Ptwo maps to P2.\n"
        self.assertEqual(self.check.name_hit_lines(sample, salt, hashes), [])

    def test_linter_flags_runtime_email_and_valid_cpf(self) -> None:
        address = "person" + "@" + "mail.invalid"
        digits = [1, 2, 3, 4, 5, 6, 7, 8, 9]

        def checksum(count: int) -> int:
            total = sum(digits[i] * (count + 1 - i) for i in range(count))
            remainder = total % 11
            return 0 if remainder < 2 else 11 - remainder

        digits.append(checksum(9))
        digits.append(checksum(10))
        cpf = "".join(str(d) for d in digits)
        self.assertTrue(self.linter.is_valid_cpf(cpf))
        findings = self.linter.scan_text("notes.md", f"Contact {address} id {cpf}\n")
        kinds = {item.pii_type for item in findings}
        self.assertIn("email", kinds)
        self.assertIn("cpf", kinds)
        blob = "\n".join(item.masked_excerpt for item in findings)
        self.assertNotIn(address, blob)
        self.assertNotIn(cpf, blob)

    def test_skill_tree_passes_names_and_linter(self) -> None:
        completed = subprocess.run(
            [sys.executable, str(CHECK_PATH)],
            cwd=REPO,
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertNotIn("denied-name", completed.stdout)

    def test_temp_tree_name_failure_hides_surface_form(self) -> None:
        sentinel = "Qxpseudonym"
        salt = "cd" * 16
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            skill = root / "skill"
            skill.mkdir()
            (skill / "notes.md").write_text(f"Hello {sentinel}\n", encoding="utf-8")
            denylist = skill / "denylist.json"
            denylist.write_text(
                json.dumps(
                    {
                        "algorithm": "sha256",
                        "salt": salt,
                        "hashes": self.check.seal([sentinel], salt),
                    }
                ),
                encoding="utf-8",
            )
            completed = subprocess.run(
                [
                    sys.executable,
                    str(CHECK_PATH),
                    "--skill-dir",
                    str(skill),
                    "--denylist",
                    str(denylist),
                    "--names-only",
                ],
                cwd=REPO,
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertEqual(completed.returncode, 1)
            self.assertIn("denied-name", completed.stdout)
            self.assertNotIn(sentinel, completed.stdout)
            self.assertNotIn(sentinel, completed.stderr)


if __name__ == "__main__":
    unittest.main()
