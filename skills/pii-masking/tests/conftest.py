"""Pytest configuration — adds the parent skill directory to sys.path.

The skill directory uses a hyphenated name (`pii-masking/`) per the
multi-agent-os skills convention, which is not a valid Python package
identifier. This conftest makes `linter_pii` importable from the test
files without forcing a rename of the skill directory.
"""

import pathlib
import sys

_SKILL_DIR = pathlib.Path(__file__).resolve().parent.parent
if str(_SKILL_DIR) not in sys.path:
    sys.path.insert(0, str(_SKILL_DIR))
