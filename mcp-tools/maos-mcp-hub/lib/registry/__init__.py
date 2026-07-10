"""lib.registry — the MAOS Hub plugin-level registry SSOT (T1 / WAVE 5).

Sibling of ``lib.gateway.tool_registry`` (WT8 — MCP-gateway-scoped records):
this package derives records for EVERY MAOS-routable tool — own skills/agents
+ integrated third-party experts — per ``openspec/specs/maos-hub-registry/spec.md``.
"""

from .hub_registry import (  # noqa: F401
    ACTIVATION_TIERS,
    HUB_REGISTRY_SCHEMA_VERSION,
    HubRecord,
    HubRegistry,
)
from .console import (  # noqa: F401
    VIEWS,
    HubConsole,
    Recipe,
    load_recipe_catalog,
)
from .gatekeeper import (  # noqa: F401
    ALLOWED_VERDICTS,
    GATEKEEPER_SCHEMA_VERSION,
    Candidate,
    IntakeGatekeeper,
)
from .context_rank import (  # noqa: F401
    extract_signals,
    load_signals_file,
    rank,
    render_ranking,
)
from .prose_intent import (  # noqa: F401
    interview_questions,
    map_prose,
    render_mapping,
)
