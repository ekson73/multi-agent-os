import asyncio

import httpx
import pytest
import respx

from lib.common.errors import AuthError, NotFoundError
from lib.jira.client import JiraClient


def _setup_env(monkeypatch):
    monkeypatch.setenv("JIRA_EMAIL", "dev@example.com")
    monkeypatch.setenv("JIRA_CLOUD_ID", "023bcd49-f455-4451-a096-c50c42c811d7")


def test_get_issue_success(monkeypatch):
    _setup_env(monkeypatch)
    monkeypatch.setenv("JIRA_API_TOKEN", "jira-token")
    monkeypatch.delenv("ATLASSIAN_API_TOKEN", raising=False)

    async def run() -> None:
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

    async def run() -> None:
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

    async def run() -> None:
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

    async def run() -> None:
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

    async def run() -> None:
        client = JiraClient()
        with respx.mock(assert_all_called=True) as router:
            router.delete(
                "https://api.atlassian.com/ex/jira/023bcd49-f455-4451-a096-c50c42c811d7/rest/api/3/attachment/30001"
            ).mock(return_value=httpx.Response(204))

            result = await client.delete_attachment("30001")
            assert result["status"] == "deleted"
            assert result["attachment_id"] == "30001"

    asyncio.run(run())


def test_delete_attachment_maps_404_to_not_found(monkeypatch):
    _setup_env(monkeypatch)
    monkeypatch.setenv("JIRA_API_TOKEN", "jira-token")
    monkeypatch.delenv("ATLASSIAN_API_TOKEN", raising=False)

    async def run() -> None:
        client = JiraClient()
        with respx.mock(assert_all_called=True) as router:
            router.delete(
                "https://api.atlassian.com/ex/jira/023bcd49-f455-4451-a096-c50c42c811d7/rest/api/3/attachment/40401"
            ).mock(return_value=httpx.Response(404, text='{"error":"not found"}'))

            with pytest.raises(NotFoundError) as exc_info:
                await client.delete_attachment("40401")
            exc = exc_info.value
            assert exc.status_code == 404
            assert "/attachment/40401" in exc.endpoint

    asyncio.run(run())


def test_delete_attachment_maps_403_to_auth_error(monkeypatch):
    _setup_env(monkeypatch)
    monkeypatch.setenv("JIRA_API_TOKEN", "jira-token")
    monkeypatch.delenv("ATLASSIAN_API_TOKEN", raising=False)

    async def run() -> None:
        client = JiraClient()
        with respx.mock(assert_all_called=True) as router:
            router.delete(
                "https://api.atlassian.com/ex/jira/023bcd49-f455-4451-a096-c50c42c811d7/rest/api/3/attachment/40301"
            ).mock(return_value=httpx.Response(403, text='{"error":"forbidden"}'))

            with pytest.raises(AuthError) as exc_info:
                await client.delete_attachment("40301")
            exc = exc_info.value
            assert exc.status_code == 403
            assert "/attachment/40301" in exc.endpoint

    asyncio.run(run())


# ========================================================================
# Agile API — Boards & Estimation
# ========================================================================

AGILE_BASE = "https://api.atlassian.com/ex/jira/023bcd49-f455-4451-a096-c50c42c811d7/rest/agile/1.0"


def test_get_boards_with_project_filter(monkeypatch):
    _setup_env(monkeypatch)
    monkeypatch.setenv("JIRA_API_TOKEN", "jira-token")
    monkeypatch.delenv("ATLASSIAN_API_TOKEN", raising=False)

    async def run() -> None:
        client = JiraClient()
        with respx.mock(assert_all_called=True) as router:
            router.get(f"{AGILE_BASE}/board").mock(
                return_value=httpx.Response(
                    200,
                    json={
                        "values": [
                            {"id": 42, "name": "VKS Board", "type": "scrum"},
                            {"id": 43, "name": "VKS Kanban", "type": "kanban"},
                        ]
                    },
                )
            )

            boards = await client.get_boards("VKS")
            assert len(boards) == 2
            assert boards[0]["id"] == 42
            assert boards[0]["name"] == "VKS Board"
            assert boards[1]["type"] == "kanban"

    asyncio.run(run())


def test_get_boards_no_filter(monkeypatch):
    _setup_env(monkeypatch)
    monkeypatch.setenv("JIRA_API_TOKEN", "jira-token")
    monkeypatch.delenv("ATLASSIAN_API_TOKEN", raising=False)

    async def run() -> None:
        client = JiraClient()
        with respx.mock(assert_all_called=True) as router:
            router.get(f"{AGILE_BASE}/board").mock(
                return_value=httpx.Response(200, json={"values": []})
            )

            boards = await client.get_boards()
            assert boards == []

    asyncio.run(run())


def test_get_estimation_success(monkeypatch):
    _setup_env(monkeypatch)
    monkeypatch.setenv("JIRA_API_TOKEN", "jira-token")
    monkeypatch.delenv("ATLASSIAN_API_TOKEN", raising=False)

    async def run() -> None:
        client = JiraClient()
        with respx.mock(assert_all_called=True) as router:
            router.get(f"{AGILE_BASE}/issue/VKS-1673/estimation").mock(
                return_value=httpx.Response(200, json={"value": 5})
            )

            result = await client.get_estimation("VKS-1673", board_id=42)
            assert result["value"] == 5

    asyncio.run(run())


def test_set_estimation_success(monkeypatch):
    _setup_env(monkeypatch)
    monkeypatch.setenv("JIRA_API_TOKEN", "jira-token")
    monkeypatch.delenv("ATLASSIAN_API_TOKEN", raising=False)

    async def run() -> None:
        client = JiraClient()
        with respx.mock(assert_all_called=True) as router:
            router.put(f"{AGILE_BASE}/issue/VKS-1673/estimation").mock(
                return_value=httpx.Response(200, json={"value": 8})
            )

            result = await client.set_estimation("VKS-1673", board_id=42, value=8)
            assert result["value"] == 8

    asyncio.run(run())


def test_set_estimation_maps_403_to_auth_error(monkeypatch):
    _setup_env(monkeypatch)
    monkeypatch.setenv("JIRA_API_TOKEN", "jira-token")
    monkeypatch.delenv("ATLASSIAN_API_TOKEN", raising=False)

    async def run() -> None:
        client = JiraClient()
        with respx.mock(assert_all_called=True) as router:
            router.put(f"{AGILE_BASE}/issue/VKS-1673/estimation").mock(
                return_value=httpx.Response(403, text='{"error":"forbidden"}')
            )

            with pytest.raises(AuthError) as exc_info:
                await client.set_estimation("VKS-1673", board_id=42, value=8)
            exc = exc_info.value
            assert exc.status_code == 403

    asyncio.run(run())


def test_get_estimation_maps_404_to_not_found(monkeypatch):
    _setup_env(monkeypatch)
    monkeypatch.setenv("JIRA_API_TOKEN", "jira-token")
    monkeypatch.delenv("ATLASSIAN_API_TOKEN", raising=False)

    async def run() -> None:
        client = JiraClient()
        with respx.mock(assert_all_called=True) as router:
            router.get(f"{AGILE_BASE}/issue/VKS-9999/estimation").mock(
                return_value=httpx.Response(404, text='{"error":"not found"}')
            )

            with pytest.raises(NotFoundError) as exc_info:
                await client.get_estimation("VKS-9999", board_id=42)
            exc = exc_info.value
            assert exc.status_code == 404

    asyncio.run(run())


# ---------------------------------------------------------------------------
# Agile — Sprints & Versions (VKS-2080 Fase 2)
# ---------------------------------------------------------------------------

API3_BASE = "https://api.atlassian.com/ex/jira/023bcd49-f455-4451-a096-c50c42c811d7/rest/api/3"


def test_get_sprints_with_state_filter(monkeypatch):
    _setup_env(monkeypatch)
    monkeypatch.setenv("JIRA_API_TOKEN", "jira-token")
    monkeypatch.delenv("ATLASSIAN_API_TOKEN", raising=False)

    async def run() -> None:
        client = JiraClient()
        with respx.mock(assert_all_called=True) as router:
            router.get(f"{AGILE_BASE}/board/59/sprint").mock(
                return_value=httpx.Response(
                    200,
                    json={"values": [{"id": 7, "name": "Sprint 1", "state": "active"}]},
                )
            )

            sprints = await client.get_sprints(59, state="active")
            assert len(sprints) == 1
            assert sprints[0]["id"] == 7
            assert sprints[0]["state"] == "active"

    asyncio.run(run())


def test_get_sprints_no_filter(monkeypatch):
    _setup_env(monkeypatch)
    monkeypatch.setenv("JIRA_API_TOKEN", "jira-token")
    monkeypatch.delenv("ATLASSIAN_API_TOKEN", raising=False)

    async def run() -> None:
        client = JiraClient()
        with respx.mock(assert_all_called=True) as router:
            router.get(f"{AGILE_BASE}/board/59/sprint").mock(
                return_value=httpx.Response(200, json={"values": []})
            )

            sprints = await client.get_sprints(59)
            assert sprints == []

    asyncio.run(run())


def test_create_sprint_success(monkeypatch):
    _setup_env(monkeypatch)
    monkeypatch.setenv("JIRA_API_TOKEN", "jira-token")
    monkeypatch.delenv("ATLASSIAN_API_TOKEN", raising=False)

    async def run() -> None:
        client = JiraClient()
        with respx.mock(assert_all_called=True) as router:
            route = router.post(f"{AGILE_BASE}/sprint").mock(
                return_value=httpx.Response(
                    201, json={"id": 99, "name": "Sprint 2026-06", "state": "future"}
                )
            )

            result = await client.create_sprint(59, "Sprint 2026-06", goal="ship v2.1")
            assert result["id"] == 99
            assert result["state"] == "future"
            # body carries originBoardId + name + goal (no blank dates)
            import json as _json
            sent = _json.loads(route.calls.last.request.content)
            assert sent == {"originBoardId": 59, "name": "Sprint 2026-06", "goal": "ship v2.1"}

    asyncio.run(run())


def test_update_sprint_partial(monkeypatch):
    _setup_env(monkeypatch)
    monkeypatch.setenv("JIRA_API_TOKEN", "jira-token")
    monkeypatch.delenv("ATLASSIAN_API_TOKEN", raising=False)

    async def run() -> None:
        client = JiraClient()
        with respx.mock(assert_all_called=True) as router:
            route = router.post(f"{AGILE_BASE}/sprint/99").mock(
                return_value=httpx.Response(200, json={"id": 99, "state": "active"})
            )

            result = await client.update_sprint(99, state="active")
            assert result["state"] == "active"
            # partial update — only the provided field is sent
            import json as _json
            sent = _json.loads(route.calls.last.request.content)
            assert sent == {"state": "active"}

    asyncio.run(run())


def test_create_version_success(monkeypatch):
    _setup_env(monkeypatch)
    monkeypatch.setenv("JIRA_API_TOKEN", "jira-token")
    monkeypatch.delenv("ATLASSIAN_API_TOKEN", raising=False)

    async def run() -> None:
        client = JiraClient()
        with respx.mock(assert_all_called=True) as router:
            route = router.post(f"{API3_BASE}/version").mock(
                return_value=httpx.Response(
                    201, json={"id": "10500", "name": "1.6.0", "released": False}
                )
            )

            result = await client.create_version(10309, "1.6.0", description="maos v1.6.0")
            assert result["id"] == "10500"
            assert result["released"] is False
            import json as _json
            sent = _json.loads(route.calls.last.request.content)
            assert sent == {
                "projectId": 10309,
                "name": "1.6.0",
                "released": False,
                "description": "maos v1.6.0",
            }

    asyncio.run(run())


def test_release_version_success(monkeypatch):
    _setup_env(monkeypatch)
    monkeypatch.setenv("JIRA_API_TOKEN", "jira-token")
    monkeypatch.delenv("ATLASSIAN_API_TOKEN", raising=False)

    async def run() -> None:
        client = JiraClient()
        with respx.mock(assert_all_called=True) as router:
            route = router.put(f"{API3_BASE}/version/10500").mock(
                return_value=httpx.Response(
                    200, json={"id": "10500", "name": "1.6.0", "released": True}
                )
            )

            result = await client.release_version("10500", release_date="2026-06-01")
            assert result["released"] is True
            import json as _json
            sent = _json.loads(route.calls.last.request.content)
            assert sent == {"released": True, "releaseDate": "2026-06-01"}

    asyncio.run(run())
