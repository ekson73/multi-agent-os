"""Static governance contract; no provider calls or runtime-enforcement claim."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class TicketFirstContract(unittest.TestCase):
    def test_protocol_invariants(self):
        text = (ROOT / "protocols/ticket-first-governance.md").read_text()
        for requirement in (
            "before implementation", "search-before-create", "visibility",
            "not authorization", "pending-ticket", "read-only recon",
            "resolved", "duplicate", "error", "next retry", "17-field",
            "acceptance criteria", "dependencies", "owner", "evidence", "PR links",
        ):
            with self.subTest(requirement=requirement):
                self.assertIn(requirement, text)

    def test_bootstrap_and_lifecycle_reference_ssot(self):
        for name in ("AGENTS.md", "skills/preflight/SKILL.md",
                     "skills/postflight/references/ticket-sync-protocol.md"):
            with self.subTest(name=name):
                self.assertIn("protocols/ticket-first-governance.md", (ROOT / name).read_text())

    def test_no_untracked_implementation_escape(self):
        text = (ROOT / "skills/preflight/SKILL.md").read_text()
        for obsolete in ("never auto-creates", "Proceed without a documented ticket",
                         "creation* is always", "create-proposal are HITL-gated"):
            self.assertNotIn(obsolete, text)
        self.assertIn("implementation remains paused", text)

    def test_pending_recovery_is_part_of_exit(self):
        text = (ROOT / "skills/postflight/references/ticket-sync-protocol.md").read_text()
        self.assertIn("pending-ticket", text)
        self.assertIn("search-before-create", text)
        self.assertNotIn("No skill, but the repo is GitHub-hosted", text)


if __name__ == "__main__":
    unittest.main()
