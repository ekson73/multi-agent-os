import asyncio

import httpx
import respx

from lib.bitbucket.client import BitbucketPipelineClient
from lib.common.errors import NotFoundError


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

