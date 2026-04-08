"""
Discovery response builder for meta-tool gateways.

Generates typed responses for each discovery level:
  Level 0: list resources
  Level 1: list operations for a resource
  Level 2: show param schema for a resource+operation
"""

from __future__ import annotations

from typing import Any, Dict, List, Optional

from .schema_registry import SchemaRegistry
from .types import AgentFeedback


def build_discovery_response(
    tool: str,
    registry: SchemaRegistry,
    resource: Optional[str] = None,
    operation: Optional[str] = None,
    governance: Optional[List[str]] = None,
) -> Dict[str, Any]:
    """Build the appropriate discovery response for the given level.

    Args:
        tool: Gateway tool name
        registry: Schema registry for this gateway
        resource: Resource name (None = level 0)
        operation: Operation name (None = level 1)
        governance: Cross-cutting governance hints

    Returns:
        dict with discovery data + _agent_feedback
    """
    feedback = AgentFeedback(
        tool=tool,
        resource=resource,
        operation=operation,
        governance=list(governance or []),
    )

    # Level 0: list all resources
    if resource is None:
        resources = registry.resources()
        feedback.hints.append(f"Available resources: {', '.join(resources)}")
        return {
            "resources": resources,
            "_agent_feedback": feedback.to_dict(),
        }

    # Validate resource exists
    if not registry.has_resource(resource):
        available = registry.resources()
        feedback.hints.append(f"Unknown resource '{resource}'. Available: {', '.join(available)}")
        return {
            "error": f"Unknown resource: {resource}",
            "available_resources": available,
            "_agent_feedback": feedback.to_dict(),
        }

    # Level 1: list operations for resource
    if operation is None:
        operations = registry.operations(resource)
        feedback.hints.append(f"Available operations for '{resource}': {', '.join(operations)}")
        return {
            "resource": resource,
            "operations": operations,
            "_agent_feedback": feedback.to_dict(),
        }

    # Validate operation exists
    if not registry.has_operation(resource, operation):
        available = registry.operations(resource)
        feedback.hints.append(
            f"Unknown operation '{operation}' for '{resource}'. Available: {', '.join(available)}"
        )
        return {
            "error": f"Unknown operation: {operation}",
            "resource": resource,
            "available_operations": available,
            "_agent_feedback": feedback.to_dict(),
        }

    # Level 2: show param schema
    schema = registry.get_schema(resource, operation)
    assert schema is not None  # validated above

    feedback.hints.append(
        f"Call with params to execute: resource='{resource}', operation='{operation}'"
    )

    return {
        "resource": resource,
        "operation": operation,
        "description": schema.description,
        "required": schema.required_params,
        "optional": schema.optional_params,
        "_agent_feedback": feedback.to_dict(),
    }
