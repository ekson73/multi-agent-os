"""
Gateway framework for meta-tools pattern.

Provides hierarchical tool routing with typed schemas per level
and governance feedback injection in every response.
"""

from .types import GatewayRequest, ActionSchema, AgentFeedback
from .router import MetaToolRouter
from .schema_registry import SchemaRegistry
from .tool_registry import (
    REGISTRY_SCHEMA_VERSION,
    ToolRecord,
    ToolRegistry,
    risk_signals_for_operation,
)
from .feedback import with_feedback
from .discovery import build_discovery_response
from .iso import (
    ISO_DEFAULT_TOP_K,
    ISO_SUMMARY_TOKEN_LIMIT,
    IsoGate,
    IsoSelection,
    ToolSummary,
    iso_tokens,
)
from .cts import (
    CTS_WEIGHTS,
    CtsCandidate,
    CtsRanking,
    CtsScorer,
    CtsTurn,
    RiskClass,
    RiskSignals,
    risk_class,
)

__all__ = [
    "ActionSchema",
    "AgentFeedback",
    "CTS_WEIGHTS",
    "CtsCandidate",
    "CtsRanking",
    "CtsScorer",
    "CtsTurn",
    "GatewayRequest",
    "ISO_DEFAULT_TOP_K",
    "ISO_SUMMARY_TOKEN_LIMIT",
    "IsoGate",
    "IsoSelection",
    "MetaToolRouter",
    "REGISTRY_SCHEMA_VERSION",
    "RiskClass",
    "RiskSignals",
    "SchemaRegistry",
    "ToolRecord",
    "ToolRegistry",
    "ToolSummary",
    "build_discovery_response",
    "iso_tokens",
    "risk_class",
    "risk_signals_for_operation",
    "with_feedback",
]
