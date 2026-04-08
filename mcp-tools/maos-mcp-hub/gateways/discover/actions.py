"""
Discover gateway — returns macro catalog of all Atlassian domains.

This is the entry point for agents that don't know which domain to use.
"""

from __future__ import annotations

from typing import Any, Dict

from lib.gateway.types import AgentFeedback

# Import routers lazily to get action counts
_DOMAIN_REGISTRY = {
    "jira": {
        "tool": "atlassian_jira",
        "purpose": "Issues, boards, sprints, estimation, comments, worklogs, links, search",
        "module": "gateways.jira.actions",
    },
    "confluence": {
        "tool": "atlassian_confluence",
        "purpose": "Pages, comments, spaces, search (CQL)",
        "module": "gateways.confluence.actions",
    },
    "bitbucket": {
        "tool": "atlassian_bitbucket",
        "purpose": "Pipelines, pull requests, branches, deployments, tests, caches",
        "module": "gateways.bitbucket.actions",
    },
    "compass": {
        "tool": "atlassian_compass",
        "purpose": "Service registry, components, relationships, custom fields",
        "module": "gateways.compass.actions",
    },
    "common": {
        "tool": "atlassian_common",
        "purpose": "User info, accessible resources, server info",
        "module": "gateways.common.actions",
    },
}


async def discover() -> Dict[str, Any]:
    """Return catalog of all available Atlassian domains."""
    domains = {}
    total_actions = 0

    for name, info in _DOMAIN_REGISTRY.items():
        try:
            import importlib
            mod = importlib.import_module(info["module"])
            router = mod.build_router()
            action_count = router.action_count
        except Exception:
            action_count = 0

        domains[name] = {
            "tool": info["tool"],
            "purpose": info["purpose"],
            "actions": action_count,
        }
        total_actions += action_count

    feedback = AgentFeedback(
        tool="atlassian_discover",
        hints=[
            "Para issues/boards/sprints → atlassian_jira",
            "Para documentacao/pages → atlassian_confluence",
            "Para PRs/pipelines/branches → atlassian_bitbucket",
            "Para service registry → atlassian_compass",
            "Para user info → atlassian_common",
        ],
        governance=[
            "Declare governance_level antes de criar artefatos",
            "DARCI roles recomendados para issues NORMAL+CRITICAL",
        ],
    )

    return {
        "domains": domains,
        "total_actions": total_actions,
        "total_gateways": len(domains),
        "_agent_feedback": feedback.to_dict(),
    }
