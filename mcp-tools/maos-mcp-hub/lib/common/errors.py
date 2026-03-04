"""
Common typed errors for external API integrations.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Optional


@dataclass
class ApiError(Exception):
    """Base structured error for upstream API failures."""

    message: str
    status_code: int
    endpoint: str
    provider: str
    hint: Optional[str] = None

    def __str__(self) -> str:
        base = (
            f"{self.provider} API error ({self.status_code}) at {self.endpoint}: "
            f"{self.message}"
        )
        if self.hint:
            return f"{base} | hint: {self.hint}"
        return base


class AuthError(ApiError):
    """Authentication/authorization failure (401/403)."""


class NotFoundError(ApiError):
    """Requested resource does not exist (404)."""


class RateLimitError(ApiError):
    """Upstream rate limit reached (429)."""


class ServerError(ApiError):
    """Upstream internal/server-side error (5xx)."""


class NetworkError(ApiError):
    """Network/timeout/transport error."""

