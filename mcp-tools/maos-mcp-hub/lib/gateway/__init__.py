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

__all__ = [
    "GatewayRequest",
    "ActionSchema",
    "AgentFeedback",
    "MetaToolRouter",
    "SchemaRegistry",
    "with_feedback",
    "build_discovery_response",
]
