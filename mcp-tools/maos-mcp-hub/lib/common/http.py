"""
Shared async HTTP helpers with retry/backoff/rate-limit and error mapping.
"""

from __future__ import annotations

import asyncio
import random
import re
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime
from typing import Any, Optional

import httpx
from aiolimiter import AsyncLimiter

from .errors import (
    ApiError,
    AuthError,
    NetworkError,
    NotFoundError,
    RateLimitError,
    ServerError,
)


def sanitize_text(value: str) -> str:
    """Redact common secrets in logs/error strings."""
    text = value
    text = re.sub(r"Basic [A-Za-z0-9+/=]+", "Basic ***", text)
    text = re.sub(r"Bearer [A-Za-z0-9._=-]+", "Bearer ***", text)
    text = re.sub(
        r"(token|password|secret|api[_-]?key)[=:\s]+[^\s,)]+",
        r"\1=***",
        text,
        flags=re.IGNORECASE,
    )
    return text


def sanitize_exception(error: Exception) -> str:
    return sanitize_text(str(error))


def _backoff_seconds(attempt: int, base: float = 0.5, cap: float = 8.0) -> float:
    # Exponential backoff + jitter to reduce thundering herd.
    delay = min(cap, base * (2 ** max(0, attempt - 1)))
    return delay + random.uniform(0, 0.3)


def _retry_after_seconds(raw: Optional[str]) -> Optional[float]:
    """Parse Retry-After header as seconds or HTTP-date."""
    if not raw:
        return None

    value = raw.strip()
    if not value:
        return None

    try:
        return max(0.0, float(value))
    except ValueError:
        pass

    try:
        dt = parsedate_to_datetime(value)
        if dt is None:
            return None
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return max(0.0, (dt - datetime.now(timezone.utc)).total_seconds())
    except (TypeError, ValueError, OverflowError):
        return None


def _retry_delay(exc: httpx.HTTPStatusError, attempt: int) -> float:
    """Honor Retry-After when present, never less than local backoff."""
    local = _backoff_seconds(attempt)
    retry_after = _retry_after_seconds(exc.response.headers.get("Retry-After"))
    if retry_after is None:
        return local
    return max(local, retry_after)


def _map_http_status_error(
    error: httpx.HTTPStatusError,
    *,
    provider: str,
    endpoint: str,
    auth_hint: str,
) -> ApiError:
    status_code = error.response.status_code
    message = sanitize_text(error.response.text or error.response.reason_phrase or str(error))

    if status_code in (401, 403):
        return AuthError(message, status_code, endpoint, provider, auth_hint)
    if status_code == 404:
        return NotFoundError(
            message,
            status_code,
            endpoint,
            provider,
            "Verifique identificadores (repo_slug, build_number, issue_key, etc.).",
        )
    if status_code == 429:
        return RateLimitError(
            message,
            status_code,
            endpoint,
            provider,
            "Rate limit atingido; tente novamente com menos frequência.",
        )
    if 500 <= status_code < 600:
        return ServerError(
            message,
            status_code,
            endpoint,
            provider,
            "Falha temporária no upstream; tente novamente em instantes.",
        )
    return ApiError(message, status_code, endpoint, provider)


async def request_json(
    *,
    method: str,
    url: str,
    provider: str,
    auth_hint: str,
    auth_kwargs: Optional[dict[str, Any]] = None,
    params: Optional[dict[str, Any]] = None,
    json: Optional[dict[str, Any]] = None,
    timeout: float = 30.0,
    follow_redirects: bool = False,
    limiter: Optional[AsyncLimiter] = None,
    max_retries: int = 3,
) -> dict[str, Any]:
    """Perform request and parse JSON with retry + structured errors.

    `max_retries` means retries after the initial attempt.
    """
    auth_kwargs = auth_kwargs or {}
    attempts = max(1, max_retries + 1)
    last_error: Optional[Exception] = None

    for attempt in range(1, attempts + 1):
        try:
            if limiter:
                async with limiter:
                    async with httpx.AsyncClient(timeout=timeout, follow_redirects=follow_redirects) as client:
                        response = await client.request(
                            method, url, params=params, json=json, **auth_kwargs
                        )
            else:
                async with httpx.AsyncClient(timeout=timeout, follow_redirects=follow_redirects) as client:
                    response = await client.request(
                        method, url, params=params, json=json, **auth_kwargs
                    )

            response.raise_for_status()
            return response.json()

        except httpx.HTTPStatusError as exc:
            mapped = _map_http_status_error(
                exc, provider=provider, endpoint=url, auth_hint=auth_hint
            )
            last_error = mapped
            if isinstance(mapped, (RateLimitError, ServerError)) and attempt < attempts:
                await asyncio.sleep(_retry_delay(exc, attempt))
                continue
            raise mapped
        except (httpx.TimeoutException, httpx.NetworkError, httpx.TransportError) as exc:
            last_error = NetworkError(
                sanitize_exception(exc),
                0,
                url,
                provider,
                "Erro de rede/transporte. Verifique conectividade e tente novamente.",
            )
            if attempt < attempts:
                await asyncio.sleep(_backoff_seconds(attempt))
                continue
            raise last_error

    if isinstance(last_error, ApiError):
        raise last_error
    raise ApiError("Erro desconhecido", 0, url, provider)


async def request_text(
    *,
    method: str,
    url: str,
    provider: str,
    auth_hint: str,
    auth_kwargs: Optional[dict[str, Any]] = None,
    params: Optional[dict[str, Any]] = None,
    timeout: float = 30.0,
    follow_redirects: bool = False,
    limiter: Optional[AsyncLimiter] = None,
    max_retries: int = 3,
) -> str:
    """Perform request and return response text with retry + structured errors.

    `max_retries` means retries after the initial attempt.
    """
    auth_kwargs = auth_kwargs or {}
    attempts = max(1, max_retries + 1)
    last_error: Optional[Exception] = None

    for attempt in range(1, attempts + 1):
        try:
            if limiter:
                async with limiter:
                    async with httpx.AsyncClient(timeout=timeout, follow_redirects=follow_redirects) as client:
                        response = await client.request(method, url, params=params, **auth_kwargs)
            else:
                async with httpx.AsyncClient(timeout=timeout, follow_redirects=follow_redirects) as client:
                    response = await client.request(method, url, params=params, **auth_kwargs)

            response.raise_for_status()
            return response.text

        except httpx.HTTPStatusError as exc:
            mapped = _map_http_status_error(
                exc, provider=provider, endpoint=url, auth_hint=auth_hint
            )
            last_error = mapped
            if isinstance(mapped, (RateLimitError, ServerError)) and attempt < attempts:
                await asyncio.sleep(_retry_delay(exc, attempt))
                continue
            raise mapped
        except (httpx.TimeoutException, httpx.NetworkError, httpx.TransportError) as exc:
            last_error = NetworkError(
                sanitize_exception(exc),
                0,
                url,
                provider,
                "Erro de rede/transporte. Verifique conectividade e tente novamente.",
            )
            if attempt < attempts:
                await asyncio.sleep(_backoff_seconds(attempt))
                continue
            raise last_error

    if isinstance(last_error, ApiError):
        raise last_error
    raise ApiError("Erro desconhecido", 0, url, provider)
