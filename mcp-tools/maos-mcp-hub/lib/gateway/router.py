"""
Meta-tool router for gateway pattern.

Routes {resource, operation, params} to the correct handler function,
or returns discovery responses when called without full params.
"""

from __future__ import annotations

from typing import Any, Callable, Dict, List, Optional

from .discovery import build_discovery_response
from .feedback import with_feedback
from .schema_registry import SchemaRegistry
from .types import GatewayRequest


class MetaToolRouter:
    """Routes gateway requests to handler functions.

    Usage::

        router = MetaToolRouter("atlassian_jira")
        router.register("issue", "get", get_issue_handler, description="Get issue by key")
        router.register("issue", "create", create_issue_handler, ...)

        # Discovery
        result = await router.dispatch(GatewayRequest())  # level 0
        result = await router.dispatch(GatewayRequest(resource="issue"))  # level 1

        # Execution
        result = await router.dispatch(GatewayRequest(
            resource="issue", operation="get", params={"issue_key": "VKS-1"}
        ))
    """

    def __init__(
        self,
        tool_name: str,
        governance: Optional[List[str]] = None,
    ) -> None:
        self.tool_name = tool_name
        self.governance = governance or []
        self.registry = SchemaRegistry()
        self._handlers: Dict[str, Dict[str, Callable]] = {}

    def register(
        self,
        resource: str,
        operation: str,
        handler: Callable,
        description: str = "",
        governance: Optional[List[str]] = None,
        next_steps: Optional[List[str]] = None,
        required_params: Optional[List[str]] = None,
        optional_params: Optional[Dict[str, str]] = None,
    ) -> None:
        """Register a handler for resource+operation pair.

        The handler is wrapped with @with_feedback and its schema
        is registered in the schema registry.
        """
        # Merge gateway-wide governance with per-action governance
        merged_governance = list(self.governance) + list(governance or [])

        # Wrap handler with feedback
        wrapped = with_feedback(
            tool=self.tool_name,
            resource=resource,
            operation=operation,
            governance=merged_governance or None,
            next_steps=next_steps,
        )(handler)

        self._handlers.setdefault(resource, {})[operation] = wrapped

        # Register schema
        self.registry.register(
            resource=resource,
            operation=operation,
            handler=handler,  # original fn for signature introspection
            description=description,
            required_params=required_params,
            optional_params=optional_params,
        )

    async def dispatch(self, request: GatewayRequest) -> Dict[str, Any]:
        """Route request to handler or return discovery response."""

        # Discovery levels 0-2
        if request.level < 3:
            return build_discovery_response(
                tool=self.tool_name,
                registry=self.registry,
                resource=request.resource,
                operation=request.operation,
                governance=self.governance,
            )

        # Execution (level 3)
        resource = request.resource
        operation = request.operation
        params = request.params if request.params is not None else {}

        # Validate params is a dict
        if not isinstance(params, dict):
            return {
                "error": "params must be a dict",
                "resource": resource,
                "operation": operation,
                "_agent_feedback": {
                    "tool": self.tool_name,
                    "hints": ["Pass params as a JSON object, e.g. {\"key\": \"value\"}"],
                },
            }

        # Validate resource
        if resource not in self._handlers:
            available = self.registry.resources()
            return {
                "error": f"Unknown resource: {resource}",
                "available_resources": available,
                "_agent_feedback": {
                    "tool": self.tool_name,
                    "hints": [f"Available resources: {', '.join(available)}"],
                },
            }

        # Validate operation
        if operation not in self._handlers[resource]:
            available = self.registry.operations(resource)
            return {
                "error": f"Unknown operation: {operation}",
                "resource": resource,
                "available_operations": available,
                "_agent_feedback": {
                    "tool": self.tool_name,
                    "resource": resource,
                    "hints": [f"Available operations for '{resource}': {', '.join(available)}"],
                },
            }

        # Dispatch to handler (already wrapped with @with_feedback)
        handler = self._handlers[resource][operation]
        return await handler(**params)

    @property
    def resources(self) -> List[str]:
        return self.registry.resources()

    @property
    def action_count(self) -> int:
        return sum(len(ops) for ops in self._handlers.values())
