"""
Feedback decorator for governance hint injection.

Every gateway response (discovery or execution) gets an _agent_feedback
block with governance rules, hints, and suggested next steps.
"""

from __future__ import annotations

import functools
from typing import Any, Callable, Dict, List, Optional

from lib.common.errors import ApiError
from lib.common.http import sanitize_exception

from .types import AgentFeedback


def with_feedback(
    tool: str,
    resource: str,
    operation: str,
    governance: Optional[List[str]] = None,
    next_steps: Optional[List[str]] = None,
) -> Callable:
    """Decorator that wraps handler responses with _agent_feedback.

    Args:
        tool: Gateway tool name (e.g., "atlassian_jira")
        resource: Resource name (e.g., "issue")
        operation: Operation name (e.g., "create")
        governance: Static governance rules for this action
        next_steps: Suggested follow-up actions

    Usage::

        @with_feedback("atlassian_jira", "issue", "create",
                       governance=["governance_level obrigatorio"])
        async def create_issue(project_key: str, ...) -> dict:
            ...
    """

    def decorator(fn: Callable) -> Callable:
        @functools.wraps(fn)
        async def wrapper(**params: Any) -> Dict[str, Any]:
            feedback = AgentFeedback(
                tool=tool,
                resource=resource,
                operation=operation,
                governance=list(governance or []),
                next_steps=list(next_steps or []),
            )

            try:
                result = await fn(**params)

                if isinstance(result, dict) and "error" in result:
                    _enrich_error_feedback(feedback, result)
                    result["_agent_feedback"] = feedback.to_dict()
                    return result

                if isinstance(result, dict):
                    result["_agent_feedback"] = feedback.to_dict()
                    return result

                return {
                    "data": result,
                    "_agent_feedback": feedback.to_dict(),
                }

            except ApiError as exc:
                _enrich_error_feedback(feedback, {"error": str(exc), "status_code": exc.status_code})
                return {
                    "error": sanitize_exception(exc),
                    "status_code": exc.status_code,
                    "hint": exc.hint,
                    "_agent_feedback": feedback.to_dict(),
                }
            except Exception as exc:
                feedback.hints.append("Unexpected error — check params and retry")
                return {
                    "error": sanitize_exception(exc),
                    "_agent_feedback": feedback.to_dict(),
                }

        return wrapper

    return decorator


def _enrich_error_feedback(feedback: AgentFeedback, error_dict: Dict[str, Any]) -> None:
    """Add contextual hints based on error type."""
    error_msg = str(error_dict.get("error", ""))
    status = error_dict.get("status_code", 0)

    if status == 401 or "unauthorized" in error_msg.lower():
        feedback.hints.append("Check credentials (JIRA_EMAIL + API token)")
    elif status == 403:
        feedback.hints.append("Permission denied — check account permissions")
    elif status == 404:
        feedback.hints.append("Resource not found — verify ID/key")
    elif status == 429:
        feedback.hints.append("Rate limit — retry with backoff")
    elif status >= 500:
        feedback.hints.append("Server error — retry or check Atlassian status")
