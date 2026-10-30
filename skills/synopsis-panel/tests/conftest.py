"""Pytest configuration — makes synopsis-fuse.py importable as a module.

The skill directory uses a hyphenated name (`synopsis-panel/`) per the
multi-agent-os skills convention, and the script itself is hyphenated
(`bin/synopsis-fuse.py`), so neither is a valid Python package or module
identifier. This conftest loads the file by path and exposes it as the
`synopsis_fuse` fixture, mirroring the sys.path shim in
`skills/pii-masking/tests/conftest.py`.
"""

import importlib.util
import pathlib
import sys

import pytest

_SKILL_DIR = pathlib.Path(__file__).resolve().parent.parent
_SCRIPT = _SKILL_DIR / "bin" / "synopsis-fuse.py"


def _load():
    spec = importlib.util.spec_from_file_location("synopsis_fuse", _SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    sys.modules["synopsis_fuse"] = mod
    spec.loader.exec_module(mod)
    return mod


@pytest.fixture(scope="session")
def synopsis_fuse():
    return _load()


@pytest.fixture(scope="session")
def script_path():
    return _SCRIPT
