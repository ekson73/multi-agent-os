"""
Schema registry for meta-tool gateways.

Stores typed schemas per (resource, operation) pair and auto-generates
parameter schemas from handler function signatures when not explicitly defined.
"""

from __future__ import annotations

import inspect
from typing import Any, Callable, Dict, List, Optional

from .types import ActionSchema


class SchemaRegistry:
    """Registry of action schemas for one gateway domain."""

    def __init__(self) -> None:
        self._schemas: Dict[str, Dict[str, ActionSchema]] = {}

    def register(
        self,
        resource: str,
        operation: str,
        handler: Callable,
        description: str = "",
        required_params: Optional[List[str]] = None,
        optional_params: Optional[Dict[str, str]] = None,
    ) -> None:
        """Register a schema for resource+operation.

        If required_params/optional_params are not provided,
        they are auto-generated from the handler's signature.
        """
        if required_params is None or optional_params is None:
            auto_req, auto_opt = _params_from_signature(handler)
            if required_params is None:
                required_params = auto_req
            if optional_params is None:
                optional_params = auto_opt

        schema = ActionSchema(
            resource=resource,
            operation=operation,
            description=description or _doc_summary(handler),
            required_params=required_params,
            optional_params=optional_params,
        )
        self._schemas.setdefault(resource, {})[operation] = schema

    def resources(self) -> List[str]:
        return sorted(self._schemas.keys())

    def operations(self, resource: str) -> List[str]:
        ops = self._schemas.get(resource, {})
        return sorted(ops.keys())

    def get_schema(self, resource: str, operation: str) -> Optional[ActionSchema]:
        return self._schemas.get(resource, {}).get(operation)

    def has_resource(self, resource: str) -> bool:
        return resource in self._schemas

    def has_operation(self, resource: str, operation: str) -> bool:
        return operation in self._schemas.get(resource, {})


def _params_from_signature(fn: Callable) -> tuple[List[str], Dict[str, str]]:
    """Extract required and optional params from function signature."""
    sig = inspect.signature(fn)
    required: List[str] = []
    optional: Dict[str, str] = {}
    for name, param in sig.parameters.items():
        if name in ("self", "cls"):
            continue
        # Skip variadic params (*args, **kwargs) — they are not named inputs
        if param.kind in (inspect.Parameter.VAR_POSITIONAL, inspect.Parameter.VAR_KEYWORD):
            continue
        if param.default is inspect.Parameter.empty:
            required.append(name)
        else:
            default_repr = repr(param.default) if param.default is not None else "null"
            optional[name] = default_repr
    return required, optional


def _doc_summary(fn: Callable) -> str:
    """First line of docstring, or empty."""
    doc = getattr(fn, "__doc__", None)
    if not doc:
        return ""
    return doc.strip().split("\n")[0].strip()
