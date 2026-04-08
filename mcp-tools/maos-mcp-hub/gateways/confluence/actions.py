"""
Confluence gateway actions — 12 actions across 4 resources.
"""

from __future__ import annotations

from typing import Optional

from lib.confluence.client import ConfluenceClient
from lib.gateway.router import MetaToolRouter
from .gateway import GATEWAY_INFO

_client: Optional[ConfluenceClient] = None


def get_client() -> ConfluenceClient:
    global _client
    if _client is None:
        _client = ConfluenceClient()
    return _client


# ---------------------------------------------------------------------------
# Handlers
# ---------------------------------------------------------------------------

async def get_page(page_id: str) -> dict:
    """Get page by ID."""
    return await get_client().get_page(page_id)


async def create_page(space_id: str, title: str, body: str, parent_id: str = "", status: str = "current") -> dict:
    """Create a page in a space."""
    return await get_client().create_page(space_id, title, body, parent_id, status)


async def update_page(page_id: str, title: str, body: str, version_number: int, status: str = "current") -> dict:
    """Update a page (requires current version number)."""
    return await get_client().update_page(page_id, title, body, version_number, status)


async def get_pages_in_space(space_id: str, limit: int = 25) -> dict:
    """List pages in a space."""
    return await get_client().get_pages_in_space(space_id, limit)


async def get_page_descendants(page_id: str) -> dict:
    """Get child pages of a page."""
    return await get_client().get_page_descendants(page_id)


async def get_spaces(limit: int = 25) -> dict:
    """List available spaces."""
    return await get_client().get_spaces(limit)


async def get_footer_comments(page_id: str) -> dict:
    """Get footer comments for a page."""
    return await get_client().get_footer_comments(page_id)


async def get_inline_comments(page_id: str) -> dict:
    """Get inline comments for a page."""
    return await get_client().get_inline_comments(page_id)


async def create_footer_comment(page_id: str, body: str) -> dict:
    """Create a footer comment on a page."""
    return await get_client().create_footer_comment(page_id, body)


async def create_inline_comment(page_id: str, body: str) -> dict:
    """Create an inline comment on a page."""
    return await get_client().create_inline_comment(page_id, body)


async def get_comment_children(comment_id: str) -> dict:
    """Get child comments of a comment."""
    return await get_client().get_comment_children(comment_id)


async def search_cql(cql: str, limit: int = 25) -> dict:
    """Search Confluence using CQL."""
    return await get_client().search_cql(cql, limit)


# ---------------------------------------------------------------------------
# Router builder
# ---------------------------------------------------------------------------

def build_router() -> MetaToolRouter:
    """Build the Confluence meta-tool router with 12 actions."""
    router = MetaToolRouter(
        tool_name=GATEWAY_INFO["tool_name"],
        governance=["Confluence operations follow documentation governance"],
    )

    # Pages
    router.register("page", "get", get_page, description="Get page by ID")
    router.register("page", "create", create_page, description="Create a new page",
                    governance=["DPIA obrigatoria se dados pessoais na pagina"],
                    next_steps=["Adicionar frontmatter conforme policy"])
    router.register("page", "update", update_page, description="Update page content",
                    governance=["Versao obrigatoria — usar version_number correto"])
    router.register("page", "list_in_space", get_pages_in_space, description="List pages in a space")
    router.register("page", "get_descendants", get_page_descendants, description="Get child pages")

    # Spaces
    router.register("space", "list", get_spaces, description="List available spaces")

    # Comments
    router.register("comment", "get_footer", get_footer_comments, description="Get footer comments")
    router.register("comment", "get_inline", get_inline_comments, description="Get inline comments")
    router.register("comment", "create_footer", create_footer_comment, description="Add footer comment")
    router.register("comment", "create_inline", create_inline_comment, description="Add inline comment")
    router.register("comment", "get_children", get_comment_children, description="Get child comments")

    # Search
    router.register("search", "cql", search_cql, description="Search using CQL")

    return router
