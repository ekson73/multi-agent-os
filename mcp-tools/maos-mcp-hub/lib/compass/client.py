"""
HTTP client for Atlassian Compass API.

Compass uses a GraphQL API at https://api.atlassian.com/graphql.
Basic Auth supported (same credentials as Jira/Confluence).
"""

import base64
import os
from typing import Any, Dict, Optional

from aiolimiter import AsyncLimiter

from lib.common.http import request_json


class CompassClient:
    """Async HTTP client for Atlassian Compass (GraphQL)."""

    def __init__(self, cloud_id: Optional[str] = None):
        self.email = os.getenv("JIRA_EMAIL")
        self.api_token = (
            os.getenv("COMPASS_API_TOKEN")
            or os.getenv("ATLASSIAN_API_TOKEN")
            or os.getenv("JIRA_API_TOKEN")
        )
        self.cloud_id = cloud_id or os.getenv("COMPASS_CLOUD_ID") or os.getenv("JIRA_CLOUD_ID")

        if not self.api_token:
            raise ValueError("Missing token for Compass.")
        if not self.email:
            raise ValueError("Missing JIRA_EMAIL.")
        if not self.cloud_id:
            raise ValueError("Missing COMPASS_CLOUD_ID or JIRA_CLOUD_ID.")

        self.graphql_url = "https://api.atlassian.com/graphql"
        self._provider_name = "Compass"
        self._auth_hint = "Verifique credenciais Atlassian."
        self.rate_limiter = AsyncLimiter(max_rate=300, time_period=3600)

        credentials = base64.b64encode(f"{self.email}:{self.api_token}".encode()).decode()
        self._auth_kwargs = {"headers": {"Authorization": f"Basic {credentials}"}}

    async def _graphql(self, query: str, variables: Optional[Dict[str, Any]] = None) -> dict:
        """Execute a GraphQL query against Compass."""
        return await request_json(
            method="POST",
            url=self.graphql_url,
            provider=self._provider_name,
            auth_hint=self._auth_hint,
            auth_kwargs=self._auth_kwargs,
            json={"query": query, "variables": variables or {}},
            timeout=30.0,
            limiter=self.rate_limiter,
        )

    async def get_component(self, component_id: str) -> dict:
        """Get a Compass component by ID."""
        query = """
        query GetComponent($id: ID!) {
            compass { component(id: $id) { id name type { id name } description labels ownerId } }
        }
        """
        return await self._graphql(query, {"id": component_id})

    async def get_components(self, cloud_id: str = "", limit: int = 25) -> dict:
        """List Compass components."""
        cid = cloud_id or self.cloud_id
        query = """
        query GetComponents($cloudId: ID!, $limit: Int) {
            compass { components(cloudId: $cloudId, first: $limit) {
                nodes { id name type { id name } description }
            } }
        }
        """
        return await self._graphql(query, {"cloudId": cid, "limit": limit})

    async def create_component(self, name: str, type_id: str, description: str = "") -> dict:
        """Create a Compass component."""
        query = """
        mutation CreateComponent($input: CreateCompassComponentInput!) {
            compass { createComponent(input: $input) { success componentDetails { id name } } }
        }
        """
        variables = {"input": {"cloudId": self.cloud_id, "name": name, "typeId": type_id}}
        if description:
            variables["input"]["description"] = description
        return await self._graphql(query, variables)

    async def create_relationship(self, source_id: str, target_id: str, type_name: str = "DEPENDS_ON") -> dict:
        """Create a relationship between two components."""
        query = """
        mutation CreateRelationship($input: CreateCompassRelationshipInput!) {
            compass { createRelationship(input: $input) { success } }
        }
        """
        return await self._graphql(query, {"input": {
            "sourceComponentId": source_id, "targetComponentId": target_id, "type": type_name,
        }})

    async def get_custom_field_definitions(self, cloud_id: str = "") -> dict:
        """List custom field definitions."""
        cid = cloud_id or self.cloud_id
        query = """
        query GetCustomFields($cloudId: ID!) {
            compass { customFieldDefinitions(cloudId: $cloudId) { nodes { id name type } } }
        }
        """
        return await self._graphql(query, {"cloudId": cid})

    async def create_custom_field_definition(self, name: str, field_type: str = "TEXT") -> dict:
        """Create a custom field definition."""
        query = """
        mutation CreateCustomField($input: CreateCompassCustomFieldDefinitionInput!) {
            compass { createCustomFieldDefinition(input: $input) { success definition { id name } } }
        }
        """
        return await self._graphql(query, {"input": {
            "cloudId": self.cloud_id, "name": name, "type": field_type,
        }})
