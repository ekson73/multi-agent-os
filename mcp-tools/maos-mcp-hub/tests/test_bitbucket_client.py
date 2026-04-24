import asyncio

import httpx
import respx

from lib.bitbucket.client import BitbucketPipelineClient
from lib.common.errors import NotFoundError, RateLimitError


def _setup_env(monkeypatch):
    monkeypatch.setenv("BITBUCKET_API_TOKEN", "test-token")
    monkeypatch.setenv("BITBUCKET_AUTH_TYPE", "bearer")
    monkeypatch.delenv("BITBUCKET_EMAIL", raising=False)
    monkeypatch.delenv("JIRA_EMAIL", raising=False)
    monkeypatch.delenv("BITBUCKET_USERNAME", raising=False)


def test_get_pipelines_success(monkeypatch):
    _setup_env(monkeypatch)

    async def run():
        client = BitbucketPipelineClient(repo_slug="workspace/repo")
        with respx.mock(assert_all_called=True) as router:
            route = router.get(
                "https://api.bitbucket.org/2.0/repositories/workspace/repo/pipelines"
            ).mock(return_value=httpx.Response(200, json={"values": [{"build_number": 10}]}))

            data = await client.get_pipelines(pagelen=1)
            assert route.called
            assert data["values"][0]["build_number"] == 10

        await client.close()

    asyncio.run(run())


def test_get_pipeline_maps_404_to_not_found(monkeypatch):
    _setup_env(monkeypatch)

    async def run():
        client = BitbucketPipelineClient(repo_slug="workspace/repo")
        with respx.mock(assert_all_called=True) as router:
            router.get(
                "https://api.bitbucket.org/2.0/repositories/workspace/repo/pipelines/999"
            ).mock(return_value=httpx.Response(404, text='{"error":"not found"}'))

            try:
                await client.get_pipeline(999)
                raise AssertionError("Expected NotFoundError was not raised")
            except NotFoundError as exc:
                assert exc.status_code == 404
                assert "workspace/repo" in exc.endpoint

        await client.close()

    asyncio.run(run())


def test_get_pipelines_retries_on_429(monkeypatch):
    _setup_env(monkeypatch)
    monkeypatch.setattr("lib.common.http._backoff_seconds", lambda *args, **kwargs: 0)

    async def run():
        client = BitbucketPipelineClient(repo_slug="workspace/repo")
        with respx.mock(assert_all_called=True) as router:
            route = router.get(
                "https://api.bitbucket.org/2.0/repositories/workspace/repo/pipelines"
            ).mock(
                side_effect=[
                    httpx.Response(429, text='{"error":"rate limit"}'),
                    httpx.Response(200, json={"values": []}),
                ]
            )

            data = await client.get_pipelines(pagelen=2)
            assert data["values"] == []
            assert route.call_count == 2

        await client.close()

    asyncio.run(run())


def test_get_pull_requests_success(monkeypatch):
    _setup_env(monkeypatch)

    async def run():
        client = BitbucketPipelineClient(repo_slug="workspace/repo")
        with respx.mock(assert_all_called=True) as router:
            route = router.get(
                "https://api.bitbucket.org/2.0/repositories/workspace/repo/pullrequests"
            ).mock(
                return_value=httpx.Response(
                    200,
                    json={"values": [{"id": 11, "title": "feat: wave1"}]},
                )
            )

            data = await client.get_pull_requests(state="OPEN", pagelen=1)
            assert route.called
            assert data["values"][0]["id"] == 11
            assert data["values"][0]["title"] == "feat: wave1"

        await client.close()

    asyncio.run(run())


def test_get_pull_request_maps_404_to_not_found(monkeypatch):
    _setup_env(monkeypatch)

    async def run():
        client = BitbucketPipelineClient(repo_slug="workspace/repo")
        with respx.mock(assert_all_called=True) as router:
            router.get(
                "https://api.bitbucket.org/2.0/repositories/workspace/repo/pullrequests/321"
            ).mock(return_value=httpx.Response(404, text='{"error":"not found"}'))

            try:
                await client.get_pull_request(321)
                raise AssertionError("Expected NotFoundError was not raised")
            except NotFoundError as exc:
                assert exc.status_code == 404
                assert "/pullrequests/321" in exc.endpoint

        await client.close()

    asyncio.run(run())


def test_get_pr_statuses_retries_on_429(monkeypatch):
    _setup_env(monkeypatch)
    monkeypatch.setattr("lib.common.http._backoff_seconds", lambda *args, **kwargs: 0)

    async def run():
        client = BitbucketPipelineClient(repo_slug="workspace/repo")
        with respx.mock(assert_all_called=True) as router:
            route = router.get(
                "https://api.bitbucket.org/2.0/repositories/workspace/repo/pullrequests/42/statuses"
            ).mock(
                side_effect=[
                    httpx.Response(429, text='{"error":"rate limit"}'),
                    httpx.Response(200, json={"values": [{"state": "SUCCESSFUL"}]}),
                ]
            )

            data = await client.get_pr_statuses(42, pagelen=5)
            assert data["values"][0]["state"] == "SUCCESSFUL"
            assert route.call_count == 2

        await client.close()

    asyncio.run(run())


def test_create_pull_request_does_not_retry_on_429(monkeypatch):
    _setup_env(monkeypatch)
    monkeypatch.setattr("lib.common.http._backoff_seconds", lambda *args, **kwargs: 0)

    async def run():
        client = BitbucketPipelineClient(repo_slug="workspace/repo")
        with respx.mock(assert_all_called=True) as router:
            route = router.post(
                "https://api.bitbucket.org/2.0/repositories/workspace/repo/pullrequests"
            ).mock(
                side_effect=[
                    httpx.Response(429, text='{"error":"rate limit"}'),
                    httpx.Response(201, json={"id": 777}),
                ]
            )

            try:
                await client.create_pull_request(
                    title="feat: no-retry-post",
                    source_branch="feature/no-retry",
                    destination_branch="main",
                )
                raise AssertionError("Expected RateLimitError was not raised")
            except RateLimitError as exc:
                assert exc.status_code == 429
                assert "/pullrequests" in exc.endpoint

            # Non-idempotent POST must not retry automatically.
            assert route.call_count == 1

        await client.close()

    asyncio.run(run())


# ---------------------------------------------------------------------------
# VKS-1853: PR interaction methods
# ---------------------------------------------------------------------------

def test_add_pr_comment_top_level_success(monkeypatch):
    """VKS-1853: add_pr_comment posts to /pullrequests/{id}/comments."""
    _setup_env(monkeypatch)

    async def run():
        client = BitbucketPipelineClient(repo_slug="workspace/repo")
        with respx.mock(assert_all_called=True) as router:
            route = router.post(
                "https://api.bitbucket.org/2.0/repositories/workspace/repo/pullrequests/42/comments"
            ).mock(return_value=httpx.Response(201, json={
                "id": 12345,
                "content": {"raw": "Bot Scorecard"},
                "user": {"display_name": "Bot"},
            }))

            data = await client.add_pr_comment(pr_id=42, content="Bot Scorecard")
            assert route.called
            assert data["id"] == 12345
            # Verify payload shape
            request = route.calls.last.request
            import json as _json
            payload = _json.loads(request.content)
            assert payload == {"content": {"raw": "Bot Scorecard"}}

        await client.close()

    asyncio.run(run())


def test_add_pr_comment_threaded_reply_includes_parent(monkeypatch):
    """VKS-1853: add_pr_comment with parent_id includes parent in payload."""
    _setup_env(monkeypatch)

    async def run():
        client = BitbucketPipelineClient(repo_slug="workspace/repo")
        with respx.mock(assert_all_called=True) as router:
            route = router.post(
                "https://api.bitbucket.org/2.0/repositories/workspace/repo/pullrequests/42/comments"
            ).mock(return_value=httpx.Response(201, json={"id": 99, "parent": {"id": 12340}}))

            data = await client.add_pr_comment(
                pr_id=42, content="Rejected: stylistic.", parent_id=12340
            )
            assert data["id"] == 99
            import json as _json
            payload = _json.loads(route.calls.last.request.content)
            assert payload == {
                "content": {"raw": "Rejected: stylistic."},
                "parent": {"id": 12340},
            }

        await client.close()

    asyncio.run(run())


def test_add_pr_comment_404_maps_to_not_found(monkeypatch):
    """VKS-1853: add_pr_comment returns NotFoundError for unknown PR."""
    _setup_env(monkeypatch)

    async def run():
        client = BitbucketPipelineClient(repo_slug="workspace/repo")
        with respx.mock(assert_all_called=True) as router:
            router.post(
                "https://api.bitbucket.org/2.0/repositories/workspace/repo/pullrequests/999/comments"
            ).mock(return_value=httpx.Response(404, text='{"error":"not found"}'))

            try:
                await client.add_pr_comment(pr_id=999, content="hi")
                raise AssertionError("Expected NotFoundError")
            except NotFoundError as exc:
                assert exc.status_code == 404

        await client.close()

    asyncio.run(run())


def test_update_pr_description_success(monkeypatch):
    """VKS-1853: update_pr_description PUTs only description field."""
    _setup_env(monkeypatch)

    async def run():
        client = BitbucketPipelineClient(repo_slug="workspace/repo")
        with respx.mock(assert_all_called=True) as router:
            route = router.put(
                "https://api.bitbucket.org/2.0/repositories/workspace/repo/pullrequests/42"
            ).mock(return_value=httpx.Response(200, json={
                "id": 42,
                "title": "Original title (preserved)",
                "description": "NEW BODY",
                "state": "OPEN",
            }))

            data = await client.update_pr_description(pr_id=42, description="NEW BODY")
            assert data["id"] == 42
            assert data["title"] == "Original title (preserved)"
            import json as _json
            payload = _json.loads(route.calls.last.request.content)
            assert payload == {"description": "NEW BODY"}

        await client.close()

    asyncio.run(run())


def test_update_pr_description_non_idempotent_no_retry(monkeypatch):
    """VKS-1853: update_pr_description must not retry on 429 (race safety)."""
    _setup_env(monkeypatch)

    async def run():
        client = BitbucketPipelineClient(repo_slug="workspace/repo")
        with respx.mock(assert_all_called=True) as router:
            route = router.put(
                "https://api.bitbucket.org/2.0/repositories/workspace/repo/pullrequests/42"
            ).mock(
                side_effect=[
                    httpx.Response(429, text='{"error":"rate limit"}'),
                    httpx.Response(200, json={"id": 42}),
                ]
            )

            try:
                await client.update_pr_description(pr_id=42, description="x")
                raise AssertionError("Expected RateLimitError")
            except RateLimitError as exc:
                assert exc.status_code == 429

            # Must not retry — protects against overwriting concurrent edits
            assert route.call_count == 1

        await client.close()

    asyncio.run(run())
