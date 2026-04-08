"""
Core types for the gateway framework.

All meta-tools use these types for request parsing, schema definition,
and feedback injection.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional


@dataclass
class GatewayRequest:
    """Parsed input for any meta-tool gateway.

    Levels:
        - resource=None              → level 0 discovery (list resources)
        - resource set, operation=None → level 1 discovery (list operations)
        - resource+operation, no params → level 2 discovery (show param schema)
        - resource+operation+params    → execution
    """

    resource: Optional[str] = None
    operation: Optional[str] = None
    params: Optional[Dict[str, Any]] = None

    @property
    def level(self) -> int:
        if self.resource is None:
            return 0
        if self.operation is None:
            return 1
        if self.params is None:
            return 2
        return 3  # execution

    @classmethod
    def parse(cls, raw: Dict[str, Any]) -> "GatewayRequest":
        return cls(
            resource=raw.get("resource") or None,
            operation=raw.get("operation") or None,
            params=raw.get("params"),
        )


@dataclass
class ActionSchema:
    """Schema definition for one resource+operation pair."""

    resource: str
    operation: str
    description: str
    required_params: List[str] = field(default_factory=list)
    optional_params: Dict[str, str] = field(default_factory=dict)


@dataclass
class AgentFeedback:
    """Governance hints returned with every response."""

    tool: str
    resource: Optional[str] = None
    operation: Optional[str] = None
    hints: List[str] = field(default_factory=list)
    governance: List[str] = field(default_factory=list)
    next_steps: List[str] = field(default_factory=list)

    def to_dict(self) -> Dict[str, Any]:
        d: Dict[str, Any] = {"tool": self.tool}
        if self.resource:
            d["resource"] = self.resource
        if self.operation:
            d["operation"] = self.operation
        if self.hints:
            d["hints"] = self.hints
        if self.governance:
            d["governance"] = self.governance
        if self.next_steps:
            d["next_steps"] = self.next_steps
        return d
