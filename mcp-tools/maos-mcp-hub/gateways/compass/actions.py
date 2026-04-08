"""Compass gateway actions — 6 actions across 3 resources."""

from __future__ import annotations
from typing import Optional
from lib.compass.client import CompassClient
from lib.gateway.router import MetaToolRouter
from .gateway import GATEWAY_INFO

_client: Optional[CompassClient] = None

def get_client() -> CompassClient:
    global _client
    if _client is None:
        _client = CompassClient()
    return _client

async def get_component(component_id: str) -> dict:
    """Get component by ID."""
    return await get_client().get_component(component_id)

async def get_components(limit: int = 25) -> dict:
    """List components."""
    return await get_client().get_components(limit=limit)

async def create_component(name: str, type_id: str, description: str = "") -> dict:
    """Create a component."""
    return await get_client().create_component(name, type_id, description)

async def create_relationship(source_id: str, target_id: str, type_name: str = "DEPENDS_ON") -> dict:
    """Create a relationship between components."""
    return await get_client().create_relationship(source_id, target_id, type_name)

async def get_custom_field_definitions() -> dict:
    """List custom field definitions."""
    return await get_client().get_custom_field_definitions()

async def create_custom_field_definition(name: str, field_type: str = "TEXT") -> dict:
    """Create a custom field definition."""
    return await get_client().create_custom_field_definition(name, field_type)

def build_router() -> MetaToolRouter:
    """Build the Compass meta-tool router with 6 actions."""
    router = MetaToolRouter(tool_name=GATEWAY_INFO["tool_name"])
    router.register("component", "get", get_component, description="Get component by ID")
    router.register("component", "list", get_components, description="List components")
    router.register("component", "create", create_component, description="Create a component")
    router.register("relationship", "create", create_relationship, description="Create relationship between components")
    router.register("custom_field", "list", get_custom_field_definitions, description="List custom field definitions")
    router.register("custom_field", "create", create_custom_field_definition, description="Create custom field definition")
    return router
