from pathlib import Path
import sys

import pytest


ROOT = Path(__file__).resolve().parent.parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))


# ---------------------------------------------------------------------------
# Canonical gateway action-count SSOT for the test suite (issue #202).
# Bump HERE — and ONLY here — when a gateway gains or loses an action.
# Consumers: tests/test_gateway_discover.py · tests/test_hub_registration.py.
# History: 96 → 99 (VKS-1853: +3 bitbucket PR ops) → 104 (VKS-2080: +5 Jira
#          Agile ops) → 105 (#151: +1 bitbucket pull_request.decline).
# ---------------------------------------------------------------------------
EXPECTED_GATEWAY_ACTIONS = {
    "jira": 27,
    "confluence": 12,
    "bitbucket": 56,
    "compass": 6,
    "common": 4,
}
EXPECTED_TOTAL_ACTIONS = sum(EXPECTED_GATEWAY_ACTIONS.values())  # 105


# Fixtures — the supported consumption surface. Tests take these as args
# instead of `from conftest import ...` (fragile in a repo with multiple
# conftest.py files / pytest sys.path caching — PR #222 review consensus).
@pytest.fixture
def expected_gateway_actions():
    return dict(EXPECTED_GATEWAY_ACTIONS)


@pytest.fixture
def expected_total_actions():
    return EXPECTED_TOTAL_ACTIONS

