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

    def test_no_anchor_prose_and_example_require_gate(self):
        text = (ROOT / "skills/preflight/SKILL.md").read_text()
        sections = (
            text.split("### R0.a —", 1)[1].split("### R0.b —", 1)[0],
            text.split("**No ticket anchor**", 1)[1].split("**On `/maos:preflight ticket`**", 1)[0],
        )
        for section in sections:
            with self.subTest(section=section):
                self.assertNotIn("or proceed", section)
                self.assertIn("R0.d before implementation", section)
                self.assertIn("bounded read-only recon", section)
                self.assertIn("already-authorized urgent containment", section)
        self.assertIn("**always exit 0**", sections[0])
        self.assertIn("never blocks", sections[1])

    def test_postflight_algorithm_preserves_visibility_and_actionable_q4(self):
        text = (ROOT / "skills/postflight/SKILL.md").read_text()
        self.assertNotIn("note/drop Q4", text)
        self.assertNotIn("body mirrors the seed", text)
        self.assertIn("Q4 only if non-actionable or explicitly cancelled", text)
        self.assertIn("body is an audience-safe projection of the seed", text)

    def test_outbox_adapter_respects_seed_contract(self):
        text = (ROOT / "protocols/ticket-first-governance.md").read_text()
        for phrase in ("documentation-only adapter", "params.context", "resume_instructions",
                       "deferred entries have no key", "read back", "compatible durable mechanism",
                       "not read by the SessionStart hook"):
            self.assertIn(phrase, text)

    def test_command_and_validator_are_wired(self):
        command = (ROOT / "commands/preflight.md").read_text()
        self.assertNotIn("HITL create-proposal", command)
        self.assertIn("R0.d before implementation", command)
        validator = (ROOT / "tests/validate-plugin.sh").read_text()
        self.assertIn('python3 "$PLUGIN_ROOT/tests/test-ticket-first-contract.py"', validator)
        self.assertIn('fail "ticket-first contract tests FAILED"', validator)

    def test_pending_recovery_is_part_of_exit(self):
        text = (ROOT / "skills/postflight/references/ticket-sync-protocol.md").read_text()
        self.assertIn("pending-ticket", text)
        self.assertIn("search-before-create", text)
        self.assertNotIn("No skill, but the repo is GitHub-hosted", text)


if __name__ == "__main__":
    unittest.main()
