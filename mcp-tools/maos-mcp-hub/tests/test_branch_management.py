"""
Tests for Branch Management tools (Sprint 8 — VKS-1647)

Covers:
- create_branch: success (201), conflict (400)
- delete_branch: success (204), not found (404), default branch (400)
- set_default_branch: success (200), not found (400), forbidden (403)
- get_branch_restrictions: success with list
- create_branch_restriction: success (201), invalid (400), forbidden (403)
- delete_branch_restriction: success (204), not found (404)
"""

import asyncio
import sys
from pathlib import Path

import httpx
import pytest
import respx

# Ensure project root is in sys.path
sys.path.insert(0, str(Path(__file__).parent.parent))

from lib.bitbucket.client import BitbucketPipelineClient


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

BASE_URL = "https://api.bitbucket.org/2.0/repositories/myworkspace/myrepo"


def _setup_env(monkeypatch):
    """Configure environment for BitbucketPipelineClient instantiation."""
    monkeypatch.setenv("BITBUCKET_USERNAME", "testuser")
    monkeypatch.setenv("BITBUCKET_APP_PASSWORD", "test-app-password")
    monkeypatch.setenv("BITBUCKET_REPO_SLUG", "myworkspace/myrepo")
    monkeypatch.delenv("BITBUCKET_API_TOKEN", raising=False)
    monkeypatch.delenv("BITBUCKET_EMAIL", raising=False)
    monkeypatch.delenv("JIRA_EMAIL", raising=False)
    monkeypatch.delenv("BITBUCKET_AUTH_TYPE", raising=False)


# ---------------------------------------------------------------------------
# create_branch
# ---------------------------------------------------------------------------


class TestCreateBranch:

    def test_create_branch_success(self, monkeypatch):
        _setup_env(monkeypatch)

        async def run():
            client = BitbucketPipelineClient()
            with respx.mock(assert_all_called=True) as router:
                router.post(f"{BASE_URL}/refs/branches").mock(
                    return_value=httpx.Response(
                        201,
                        json={
                            "name": "main",
                            "target": {
                                "hash": "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2",
                                "type": "commit",
                            },
                            "type": "branch",
                        },
                    )
                )
                result = await client.create_branch(
                    name="main", target_hash="a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2"
                )
                assert result["name"] == "main"
                assert result["target"]["hash"] == "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2"

        asyncio.run(run())

    def test_create_branch_already_exists(self, monkeypatch):
        _setup_env(monkeypatch)

        async def run():
            client = BitbucketPipelineClient()
            with respx.mock() as router:
                router.post(f"{BASE_URL}/refs/branches").mock(
                    return_value=httpx.Response(
                        400,
                        json={"error": {"message": "Branch already exists"}},
                    )
                )
                from lib.common.errors import ApiError

                with pytest.raises(ApiError) as exc_info:
                    await client.create_branch(name="main", target_hash="abc123")
                assert exc_info.value.status_code == 400

        asyncio.run(run())

    def test_create_branch_with_short_hash(self, monkeypatch):
        _setup_env(monkeypatch)

        async def run():
            client = BitbucketPipelineClient()
            with respx.mock(assert_all_called=True) as router:
                route = router.post(f"{BASE_URL}/refs/branches").mock(
                    return_value=httpx.Response(
                        201,
                        json={
                            "name": "feature/test",
                            "target": {"hash": "abc1234def5678"},
                            "type": "branch",
                        },
                    )
                )
                result = await client.create_branch(
                    name="feature/test", target_hash="abc1234"
                )
                assert result["name"] == "feature/test"
                # Verify payload sent correct hash
                request = route.calls[0].request
                import json
                body = json.loads(request.content)
                assert body["name"] == "feature/test"
                assert body["target"]["hash"] == "abc1234"

        asyncio.run(run())


# ---------------------------------------------------------------------------
# delete_branch
# ---------------------------------------------------------------------------


class TestDeleteBranch:

    def test_delete_branch_success(self, monkeypatch):
        _setup_env(monkeypatch)

        async def run():
            client = BitbucketPipelineClient()
            with respx.mock(assert_all_called=True) as router:
                router.delete(f"{BASE_URL}/refs/branches/feature%2Fold-branch").mock(
                    return_value=httpx.Response(204)
                )
                status = await client.delete_branch(name="feature/old-branch")
                assert status == 204

        asyncio.run(run())

    def test_delete_branch_not_found(self, monkeypatch):
        _setup_env(monkeypatch)

        async def run():
            client = BitbucketPipelineClient()
            with respx.mock() as router:
                router.delete(f"{BASE_URL}/refs/branches/nonexistent").mock(
                    return_value=httpx.Response(
                        404, json={"error": {"message": "Branch not found"}}
                    )
                )
                from lib.common.errors import NotFoundError

                with pytest.raises(NotFoundError):
                    await client.delete_branch(name="nonexistent")

        asyncio.run(run())

    def test_delete_default_branch_rejected(self, monkeypatch):
        _setup_env(monkeypatch)

        async def run():
            client = BitbucketPipelineClient()
            with respx.mock() as router:
                router.delete(f"{BASE_URL}/refs/branches/main").mock(
                    return_value=httpx.Response(
                        400,
                        json={"error": {"message": "Cannot delete default branch"}},
                    )
                )
                from lib.common.errors import ApiError

                with pytest.raises(ApiError) as exc_info:
                    await client.delete_branch(name="main")
                assert exc_info.value.status_code == 400

        asyncio.run(run())

    def test_delete_branch_url_encodes_slashes(self, monkeypatch):
        _setup_env(monkeypatch)

        async def run():
            client = BitbucketPipelineClient()
            with respx.mock(assert_all_called=True) as router:
                # feature/deep/nested → feature%2Fdeep%2Fnested
                router.delete(
                    f"{BASE_URL}/refs/branches/feature%2Fdeep%2Fnested"
                ).mock(return_value=httpx.Response(204))
                status = await client.delete_branch(name="feature/deep/nested")
                assert status == 204

        asyncio.run(run())


# ---------------------------------------------------------------------------
# set_default_branch
# ---------------------------------------------------------------------------


class TestSetDefaultBranch:

    def test_set_default_branch_success(self, monkeypatch):
        _setup_env(monkeypatch)

        async def run():
            client = BitbucketPipelineClient()
            with respx.mock(assert_all_called=True) as router:
                route = router.put(BASE_URL).mock(
                    return_value=httpx.Response(
                        200,
                        json={
                            "name": "myrepo",
                            "full_name": "myworkspace/myrepo",
                            "mainbranch": {"name": "main", "type": "branch"},
                            "type": "repository",
                        },
                    )
                )
                result = await client.set_default_branch(name="main")
                assert result["mainbranch"]["name"] == "main"
                # Verify payload
                import json
                body = json.loads(route.calls[0].request.content)
                assert body == {"mainbranch": {"name": "main"}}

        asyncio.run(run())

    def test_set_default_branch_nonexistent(self, monkeypatch):
        _setup_env(monkeypatch)

        async def run():
            client = BitbucketPipelineClient()
            with respx.mock() as router:
                router.put(BASE_URL).mock(
                    return_value=httpx.Response(
                        400,
                        json={"error": {"message": "Branch does not exist"}},
                    )
                )
                from lib.common.errors import ApiError

                with pytest.raises(ApiError) as exc_info:
                    await client.set_default_branch(name="nonexistent")
                assert exc_info.value.status_code == 400

        asyncio.run(run())

    def test_set_default_branch_forbidden(self, monkeypatch):
        _setup_env(monkeypatch)

        async def run():
            client = BitbucketPipelineClient()
            with respx.mock() as router:
                router.put(BASE_URL).mock(
                    return_value=httpx.Response(
                        403,
                        json={"error": {"message": "Forbidden"}},
                    )
                )
                from lib.common.errors import AuthError

                with pytest.raises(AuthError):
                    await client.set_default_branch(name="main")

        asyncio.run(run())


# ---------------------------------------------------------------------------
# get_branch_restrictions
# ---------------------------------------------------------------------------


class TestGetBranchRestrictions:

    def test_get_branch_restrictions_success(self, monkeypatch):
        _setup_env(monkeypatch)

        async def run():
            client = BitbucketPipelineClient()
            with respx.mock(assert_all_called=True) as router:
                router.get(f"{BASE_URL}/branch-restrictions").mock(
                    return_value=httpx.Response(
                        200,
                        json={
                            "pagelen": 100,
                            "size": 2,
                            "values": [
                                {
                                    "id": 1001,
                                    "kind": "push",
                                    "pattern": "main",
                                    "type": "branchrestriction",
                                    "users": [],
                                    "groups": [],
                                },
                                {
                                    "id": 1002,
                                    "kind": "delete",
                                    "pattern": "release/*",
                                    "type": "branchrestriction",
                                    "users": [],
                                    "groups": [{"slug": "admins", "type": "group"}],
                                },
                            ],
                        },
                    )
                )
                result = await client.get_branch_restrictions()
                assert len(result["values"]) == 2
                assert result["values"][0]["kind"] == "push"
                assert result["values"][1]["pattern"] == "release/*"

        asyncio.run(run())

    def test_get_branch_restrictions_empty(self, monkeypatch):
        _setup_env(monkeypatch)

        async def run():
            client = BitbucketPipelineClient()
            with respx.mock(assert_all_called=True) as router:
                router.get(f"{BASE_URL}/branch-restrictions").mock(
                    return_value=httpx.Response(
                        200,
                        json={"pagelen": 100, "size": 0, "values": []},
                    )
                )
                result = await client.get_branch_restrictions()
                assert result["values"] == []
                assert result["size"] == 0

        asyncio.run(run())


# ---------------------------------------------------------------------------
# create_branch_restriction
# ---------------------------------------------------------------------------


class TestCreateBranchRestriction:

    def test_create_restriction_success(self, monkeypatch):
        _setup_env(monkeypatch)

        async def run():
            client = BitbucketPipelineClient()
            with respx.mock(assert_all_called=True) as router:
                route = router.post(f"{BASE_URL}/branch-restrictions").mock(
                    return_value=httpx.Response(
                        201,
                        json={
                            "id": 1003,
                            "kind": "push",
                            "pattern": "main",
                            "type": "branchrestriction",
                            "users": [],
                            "groups": [],
                        },
                    )
                )
                result = await client.create_branch_restriction(
                    kind="push", pattern="main"
                )
                assert result["id"] == 1003
                assert result["kind"] == "push"
                assert result["pattern"] == "main"
                # Verify payload
                import json
                body = json.loads(route.calls[0].request.content)
                assert body["kind"] == "push"
                assert body["pattern"] == "main"
                assert "users" not in body
                assert "groups" not in body

        asyncio.run(run())

    def test_create_restriction_with_users_and_groups(self, monkeypatch):
        _setup_env(monkeypatch)

        async def run():
            client = BitbucketPipelineClient()
            with respx.mock(assert_all_called=True) as router:
                route = router.post(f"{BASE_URL}/branch-restrictions").mock(
                    return_value=httpx.Response(
                        201,
                        json={
                            "id": 1004,
                            "kind": "force",
                            "pattern": "release/*",
                            "type": "branchrestriction",
                            "users": [{"uuid": "{user-uuid-1}", "type": "user"}],
                            "groups": [{"slug": "senior-devs", "type": "group"}],
                        },
                    )
                )
                result = await client.create_branch_restriction(
                    kind="force",
                    pattern="release/*",
                    users=["{user-uuid-1}"],
                    groups=["senior-devs"],
                )
                assert result["id"] == 1004
                # Verify payload includes users and groups
                import json
                body = json.loads(route.calls[0].request.content)
                assert body["users"] == [{"uuid": "{user-uuid-1}"}]
                assert body["groups"] == [{"slug": "senior-devs"}]

        asyncio.run(run())

    def test_create_restriction_invalid_kind(self, monkeypatch):
        _setup_env(monkeypatch)

        async def run():
            client = BitbucketPipelineClient()
            with respx.mock() as router:
                router.post(f"{BASE_URL}/branch-restrictions").mock(
                    return_value=httpx.Response(
                        400,
                        json={"error": {"message": "Invalid kind"}},
                    )
                )
                from lib.common.errors import ApiError

                with pytest.raises(ApiError) as exc_info:
                    await client.create_branch_restriction(
                        kind="invalid_kind", pattern="main"
                    )
                assert exc_info.value.status_code == 400

        asyncio.run(run())

    def test_create_restriction_forbidden(self, monkeypatch):
        _setup_env(monkeypatch)

        async def run():
            client = BitbucketPipelineClient()
            with respx.mock() as router:
                router.post(f"{BASE_URL}/branch-restrictions").mock(
                    return_value=httpx.Response(
                        403,
                        json={"error": {"message": "Admin access required"}},
                    )
                )
                from lib.common.errors import AuthError

                with pytest.raises(AuthError):
                    await client.create_branch_restriction(
                        kind="push", pattern="main"
                    )

        asyncio.run(run())


# ---------------------------------------------------------------------------
# delete_branch_restriction
# ---------------------------------------------------------------------------


class TestDeleteBranchRestriction:

    def test_delete_restriction_success(self, monkeypatch):
        _setup_env(monkeypatch)

        async def run():
            client = BitbucketPipelineClient()
            with respx.mock(assert_all_called=True) as router:
                router.delete(f"{BASE_URL}/branch-restrictions/1001").mock(
                    return_value=httpx.Response(204)
                )
                status = await client.delete_branch_restriction(restriction_id=1001)
                assert status == 204

        asyncio.run(run())

    def test_delete_restriction_not_found(self, monkeypatch):
        _setup_env(monkeypatch)

        async def run():
            client = BitbucketPipelineClient()
            with respx.mock() as router:
                router.delete(f"{BASE_URL}/branch-restrictions/9999").mock(
                    return_value=httpx.Response(
                        404,
                        json={"error": {"message": "Restriction not found"}},
                    )
                )
                from lib.common.errors import NotFoundError

                with pytest.raises(NotFoundError):
                    await client.delete_branch_restriction(restriction_id=9999)

        asyncio.run(run())

    def test_delete_restriction_forbidden(self, monkeypatch):
        _setup_env(monkeypatch)

        async def run():
            client = BitbucketPipelineClient()
            with respx.mock() as router:
                router.delete(f"{BASE_URL}/branch-restrictions/1001").mock(
                    return_value=httpx.Response(
                        403,
                        json={"error": {"message": "Admin access required"}},
                    )
                )
                from lib.common.errors import AuthError

                with pytest.raises(AuthError):
                    await client.delete_branch_restriction(restriction_id=1001)

        asyncio.run(run())
