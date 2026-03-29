"""
Tests for multi-persona account parameter:
- validate_account_id normalization and validation
- for_account credential resolution
- get_client_for_account caching and eviction
"""

import asyncio

import httpx
import pytest
import respx

from lib.bitbucket.client import (
    BitbucketPipelineClient,
    MAX_ACCOUNT_CLIENTS,
    _VALID_ACCOUNT_ID_RE,
)


# -----------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------

def _setup_default_env(monkeypatch):
    """Set minimal env vars for the *default* (bot) client."""
    monkeypatch.setenv("BITBUCKET_API_TOKEN", "bot-token")
    monkeypatch.setenv("BITBUCKET_AUTH_TYPE", "bearer")
    monkeypatch.delenv("BITBUCKET_EMAIL", raising=False)
    monkeypatch.delenv("JIRA_EMAIL", raising=False)
    monkeypatch.delenv("BITBUCKET_USERNAME", raising=False)
    monkeypatch.delenv("BITBUCKET_REPO_SLUG", raising=False)


def _setup_account_env(monkeypatch, account_id: str, token: str = "acct-token",
                       username: str = "acct-user", auth_type: str = "basic"):
    """Set env vars for a named account."""
    upper = account_id.upper()
    monkeypatch.setenv(f"BITBUCKET_ACCOUNT_{upper}_APP_PASSWORD", token)
    monkeypatch.setenv(f"BITBUCKET_ACCOUNT_{upper}_USERNAME", username)
    monkeypatch.setenv(f"BITBUCKET_ACCOUNT_{upper}_AUTH_TYPE", auth_type)


# -----------------------------------------------------------------------
# validate_account_id
# -----------------------------------------------------------------------

class TestValidateAccountId:
    def test_valid_simple(self):
        assert BitbucketPipelineClient.validate_account_id("emilson") == "emilson"

    def test_normalizes_whitespace_and_case(self):
        assert BitbucketPipelineClient.validate_account_id("  Emilson  ") == "emilson"

    def test_allows_hyphens_and_underscores(self):
        assert BitbucketPipelineClient.validate_account_id("my-account_1") == "my-account_1"

    def test_rejects_spaces_in_middle(self):
        with pytest.raises(ValueError, match="Invalid account_id"):
            BitbucketPipelineClient.validate_account_id("my account")

    def test_rejects_special_characters(self):
        with pytest.raises(ValueError, match="Invalid account_id"):
            BitbucketPipelineClient.validate_account_id("acct@evil")

    def test_rejects_path_traversal(self):
        with pytest.raises(ValueError, match="Invalid account_id"):
            BitbucketPipelineClient.validate_account_id("../etc")

    def test_rejects_leading_hyphen(self):
        with pytest.raises(ValueError, match="Invalid account_id"):
            BitbucketPipelineClient.validate_account_id("-starts-bad")

    def test_rejects_leading_underscore(self):
        with pytest.raises(ValueError, match="Invalid account_id"):
            BitbucketPipelineClient.validate_account_id("_starts-bad")

    def test_rejects_empty_after_strip(self):
        with pytest.raises(ValueError, match="Invalid account_id"):
            BitbucketPipelineClient.validate_account_id("   ")


# -----------------------------------------------------------------------
# for_account
# -----------------------------------------------------------------------

class TestForAccount:
    def test_default_falls_back_to_init(self, monkeypatch):
        _setup_default_env(monkeypatch)
        monkeypatch.setenv("BITBUCKET_REPO_SLUG", "ws/repo")
        client = BitbucketPipelineClient.for_account("default", repo_slug="ws/repo")
        assert client.api_token == "bot-token"
        assert client.use_bearer is True

    def test_empty_falls_back_to_init(self, monkeypatch):
        _setup_default_env(monkeypatch)
        monkeypatch.setenv("BITBUCKET_REPO_SLUG", "ws/repo")
        client = BitbucketPipelineClient.for_account("", repo_slug="ws/repo")
        assert client.api_token == "bot-token"

    def test_whitespace_default_falls_back(self, monkeypatch):
        _setup_default_env(monkeypatch)
        monkeypatch.setenv("BITBUCKET_REPO_SLUG", "ws/repo")
        client = BitbucketPipelineClient.for_account("  DEFAULT  ", repo_slug="ws/repo")
        assert client.api_token == "bot-token"

    def test_named_account_reads_prefixed_env(self, monkeypatch):
        _setup_default_env(monkeypatch)
        _setup_account_env(monkeypatch, "emilson")
        client = BitbucketPipelineClient.for_account("emilson", repo_slug="ws/repo")
        assert client.api_token == "acct-token"
        assert client.auth_user == "acct-user"
        assert client.use_bearer is False

    def test_normalization_applied(self, monkeypatch):
        """' Emilson ' should normalize to 'emilson' and find EMILSON_ env vars."""
        _setup_default_env(monkeypatch)
        _setup_account_env(monkeypatch, "emilson")
        client = BitbucketPipelineClient.for_account(" Emilson ", repo_slug="ws/repo")
        assert client.api_token == "acct-token"

    def test_missing_credentials_raises(self, monkeypatch):
        _setup_default_env(monkeypatch)
        # No BITBUCKET_ACCOUNT_GHOST_* env vars set.
        with pytest.raises(ValueError, match="No credentials found"):
            BitbucketPipelineClient.for_account("ghost", repo_slug="ws/repo")

    def test_invalid_account_raises(self, monkeypatch):
        _setup_default_env(monkeypatch)
        with pytest.raises(ValueError, match="Invalid account_id"):
            BitbucketPipelineClient.for_account("evil;rm -rf /", repo_slug="ws/repo")

    def test_bearer_account(self, monkeypatch):
        _setup_default_env(monkeypatch)
        _setup_account_env(monkeypatch, "svc", token="ATCTT3xlegacy-token", auth_type="bearer")
        client = BitbucketPipelineClient.for_account("svc", repo_slug="ws/repo")
        assert client.use_bearer is True
        assert "Bearer ATCTT3xlegacy-token" in str(client._auth_kwargs)


# -----------------------------------------------------------------------
# get_client_for_account (caching + eviction)
# -----------------------------------------------------------------------

class TestGetClientForAccount:
    def test_caches_by_normalized_key(self, monkeypatch):
        _setup_default_env(monkeypatch)
        _setup_account_env(monkeypatch, "emilson")
        monkeypatch.setenv("BITBUCKET_REPO_SLUG", "ws/repo")

        # Import after env setup so module-level code does not fail
        from servers.bitbucket.tools import get_client_for_account, _account_clients
        _account_clients.clear()

        c1 = get_client_for_account(account="emilson", repo_slug="ws/repo")
        c2 = get_client_for_account(account=" Emilson ", repo_slug="ws/repo")
        assert c1 is c2, "Normalized account should hit the same cache entry"

    def test_default_account_skips_cache(self, monkeypatch):
        _setup_default_env(monkeypatch)
        monkeypatch.setenv("BITBUCKET_REPO_SLUG", "ws/repo")

        from servers.bitbucket.tools import get_client_for_account, _account_clients
        _account_clients.clear()

        get_client_for_account(account="default")
        assert len(_account_clients) == 0

    def test_eviction_at_max_capacity(self, monkeypatch):
        """When the cache reaches MAX_ACCOUNT_CLIENTS, the oldest entry is evicted."""
        _setup_default_env(monkeypatch)
        monkeypatch.setenv("BITBUCKET_REPO_SLUG", "ws/repo")

        from servers.bitbucket.tools import get_client_for_account, _account_clients
        _account_clients.clear()

        # Fill the cache to max capacity
        for i in range(MAX_ACCOUNT_CLIENTS):
            acct = f"user{i}"
            _setup_account_env(monkeypatch, acct)
            get_client_for_account(account=acct, repo_slug="ws/repo")

        assert len(_account_clients) == MAX_ACCOUNT_CLIENTS
        first_key = next(iter(_account_clients))

        # Add one more -- should evict the first
        _setup_account_env(monkeypatch, "overflow")
        get_client_for_account(account="overflow", repo_slug="ws/repo")

        assert len(_account_clients) == MAX_ACCOUNT_CLIENTS
        assert first_key not in _account_clients
        assert "overflow:ws/repo" in _account_clients

    def test_invalid_account_raises(self, monkeypatch):
        _setup_default_env(monkeypatch)

        from servers.bitbucket.tools import get_client_for_account
        with pytest.raises(ValueError, match="Invalid account_id"):
            get_client_for_account(account="bad!acct")


# -----------------------------------------------------------------------
# _configure_auth / _configure_repo (refactored shared methods)
# -----------------------------------------------------------------------

class TestConfigureHelpers:
    def test_configure_auth_bearer(self, monkeypatch):
        _setup_default_env(monkeypatch)
        monkeypatch.setenv("BITBUCKET_REPO_SLUG", "ws/repo")
        client = BitbucketPipelineClient(repo_slug="ws/repo")
        assert client.use_bearer is True
        assert "Bearer" in str(client._auth_kwargs)

    def test_configure_auth_basic(self, monkeypatch):
        monkeypatch.setenv("BITBUCKET_API_TOKEN", "basic-token")
        monkeypatch.setenv("BITBUCKET_AUTH_TYPE", "basic")
        monkeypatch.setenv("BITBUCKET_EMAIL", "user@example.com")
        monkeypatch.setenv("BITBUCKET_REPO_SLUG", "ws/repo")
        monkeypatch.delenv("BITBUCKET_APP_PASSWORD", raising=False)
        client = BitbucketPipelineClient(repo_slug="ws/repo")
        assert client.use_bearer is False
        assert client.auth_user == "user@example.com"

    def test_configure_repo_sets_base_url(self, monkeypatch):
        _setup_default_env(monkeypatch)
        client = BitbucketPipelineClient(repo_slug="myws/myrepo")
        assert client.base_url == "https://api.bitbucket.org/2.0/repositories/myws/myrepo"
        assert client.repo_slug == "myws/myrepo"


# -----------------------------------------------------------------------
# Regex pattern sanity
# -----------------------------------------------------------------------

class TestAccountIdRegex:
    @pytest.mark.parametrize("value", ["a", "abc", "a1", "my-acct", "my_acct", "a-b-c_1"])
    def test_valid_patterns(self, value):
        assert _VALID_ACCOUNT_ID_RE.match(value)

    @pytest.mark.parametrize("value", ["", "-abc", "_abc", " abc", "a b", "a@b", "a.b", "../x"])
    def test_invalid_patterns(self, value):
        assert not _VALID_ACCOUNT_ID_RE.match(value)
