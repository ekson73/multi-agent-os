import asyncio

import httpx
import respx

from lib.common.errors import AuthError
from lib.jira.client import JiraClient


def _setup_env(monkeypatch):
    monkeypatch.setenv("JIRA_EMAIL", "dev@example.com")
    monkeypatch.setenv("JIRA_CLOUD_ID", "023bcd49-f455-4451-a096-c50c42c811d7")


def test_get_issue_success(monkeypatch):
    _setup_env(monkeypatch)
    monkeypatch.setenv("JIRA_API_TOKEN", "jira-token")
    monkeypatch.delenv("ATLASSIAN_API_TOKEN", raising=False)

    async def run():
        client = JiraClient()
        with respx.mock(assert_all_called=True) as router:
            router.get(
                "https://api.atlassian.com/ex/jira/023bcd49-f455-4451-a096-c50c42c811d7/rest/api/3/issue/VKS-1247"
            ).mock(return_value=httpx.Response(200, json={"key": "VKS-1247", "fields": {"summary": "ok"}}))

            issue = await client.get_issue("VKS-1247")
            assert issue["key"] == "VKS-1247"
            assert issue["fields"]["summary"] == "ok"

    asyncio.run(run())


def test_get_issue_maps_401_to_auth_error(monkeypatch):
    _setup_env(monkeypatch)
    monkeypatch.setenv("JIRA_API_TOKEN", "jira-token")
    monkeypatch.delenv("ATLASSIAN_API_TOKEN", raising=False)

    async def run():
        client = JiraClient()
        with respx.mock(assert_all_called=True) as router:
            router.get(
                "https://api.atlassian.com/ex/jira/023bcd49-f455-4451-a096-c50c42c811d7/rest/api/3/issue/VKS-1248"
            ).mock(return_value=httpx.Response(401, text='{"error":"unauthorized"}'))

            try:
                await client.get_issue("VKS-1248")
                raise AssertionError("Expected AuthError was not raised")
            except AuthError as exc:
                assert exc.status_code == 401
                assert "JIRA_EMAIL" in (exc.hint or "")

    asyncio.run(run())


def test_jira_fallback_to_atlassian_token(monkeypatch):
    _setup_env(monkeypatch)
    monkeypatch.delenv("JIRA_API_TOKEN", raising=False)
    monkeypatch.setenv("ATLASSIAN_API_TOKEN", "shared-token")

    client = JiraClient()
    assert client.api_token == "shared-token"


def test_download_attachment_success(monkeypatch):
    _setup_env(monkeypatch)
    monkeypatch.setenv("JIRA_API_TOKEN", "jira-token")
    monkeypatch.delenv("ATLASSIAN_API_TOKEN", raising=False)

    async def run():
        client = JiraClient()
        with respx.mock(assert_all_called=True) as router:
            router.get(
                "https://api.atlassian.com/ex/jira/023bcd49-f455-4451-a096-c50c42c811d7/rest/api/3/attachment/10001"
            ).mock(return_value=httpx.Response(200, json={"id": "10001", "content": "https://api.atlassian.com/mock/content/10001"}))
            router.get("https://api.atlassian.com/mock/content/10001").mock(return_value=httpx.Response(200, content=b"hello-md"))

            content = await client.download_attachment("10001")
            assert content == b"hello-md"

    asyncio.run(run())


def test_upload_attachment_success(monkeypatch, tmp_path):
    _setup_env(monkeypatch)
    monkeypatch.setenv("JIRA_API_TOKEN", "jira-token")
    monkeypatch.delenv("ATLASSIAN_API_TOKEN", raising=False)

    file_path = tmp_path / "sample.md"
    file_path.write_text("# sample\n", encoding="utf-8")

    async def run():
        client = JiraClient()
        with respx.mock(assert_all_called=True) as router:
            router.post(
                "https://api.atlassian.com/ex/jira/023bcd49-f455-4451-a096-c50c42c811d7/rest/api/3/issue/VKS-1247/attachments"
            ).mock(return_value=httpx.Response(200, json=[{"id": "20001", "filename": "sample.md"}]))

            result = await client.upload_attachment("VKS-1247", str(file_path))
            assert result["id"] == "20001"
            assert result["filename"] == "sample.md"

    asyncio.run(run())


def test_delete_attachment_success(monkeypatch):
    _setup_env(monkeypatch)
    monkeypatch.setenv("JIRA_API_TOKEN", "jira-token")
    monkeypatch.delenv("ATLASSIAN_API_TOKEN", raising=False)

    async def run():
        client = JiraClient()
        with respx.mock(assert_all_called=True) as router:
            router.delete(
                "https://api.atlassian.com/ex/jira/023bcd49-f455-4451-a096-c50c42c811d7/rest/api/3/attachment/30001"
            ).mock(return_value=httpx.Response(204))

            result = await client.delete_attachment("30001")
            assert result["status"] == "deleted"
            assert result["attachment_id"] == "30001"

    asyncio.run(run())
