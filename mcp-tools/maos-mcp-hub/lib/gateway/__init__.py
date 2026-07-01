"""
Gateway framework for meta-tools pattern.

Provides hierarchical tool routing with typed schemas per level
and governance feedback injection in every response.
"""

from .types import GatewayRequest, ActionSchema, AgentFeedback
from .router import MetaToolRouter
from .schema_registry import SchemaRegistry
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

__all__ = [
    "ActionSchema",
    "AgentFeedback",
    "GatewayRequest",
    "ISO_DEFAULT_TOP_K",
    "ISO_SUMMARY_TOKEN_LIMIT",
    "IsoGate",
    "IsoSelection",
    "MetaToolRouter",
    "SchemaRegistry",
    "ToolSummary",
    "build_discovery_response",
    "iso_tokens",
    "with_feedback",
]
