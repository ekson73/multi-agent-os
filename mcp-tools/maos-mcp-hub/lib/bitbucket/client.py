"""
HTTP client for Bitbucket Cloud Pipelines API v2.0

This module provides an async HTTP client for interacting with the
Bitbucket Cloud REST API to monitor and analyze pipelines.
"""

import httpx
import os
import subprocess
import re
from typing import Optional
from urllib.parse import quote
from aiolimiter import AsyncLimiter

from lib.common.http import request_json, request_text, request_empty

_VALID_ACCOUNT_ID_RE = re.compile(r"^[a-z0-9][a-z0-9_-]*$")

# Maximum number of per-account client instances kept in memory.
# Once the limit is reached the oldest entry (FIFO) is evicted.
MAX_ACCOUNT_CLIENTS = 32


class BitbucketPipelineClient:
    """
    Async HTTP client for Bitbucket Cloud Pipelines API v2.0

    Handles authentication, API calls, and response parsing.
    Supports both Basic Auth and Bearer tokens.

    Environment variables:
        BITBUCKET_EMAIL: Atlassian account email (preferred for Basic Auth with API token)
        JIRA_EMAIL: Shared fallback email for Basic Auth principal
        BITBUCKET_USERNAME: Bitbucket username (legacy/basic fallback)
        BITBUCKET_API_TOKEN: Bitbucket API token (primary variable)
        BITBUCKET_APP_PASSWORD: Legacy fallback variable (deprecated alias)
        BITBUCKET_REPO_SLUG: Override repo slug (format: workspace/repo-name)
    """

    # ------------------------------------------------------------------
    # Private helpers (shared between __init__ and for_account)
    # ------------------------------------------------------------------

    def _configure_auth(self, auth_user: Optional[str], api_token: str, auth_type: str) -> None:
        """Resolve auth strategy and pre-compute httpx auth kwargs.

        Args:
            auth_user: Basic-auth principal (email or username). May be None for bearer.
            api_token: API token or app password.
            auth_type: Explicit auth type ("bearer" or "basic"), or empty for auto-detect.
        """
        self.auth_user = auth_user
        self.api_token = api_token

        auth_type = (auth_type or "").strip().lower()
        if auth_type in {"bearer", "basic"}:
            self.use_bearer = auth_type == "bearer"
        else:
            # Auto-detect bearer token format unless auth type is explicitly forced.
            # Official Bitbucket API tokens use Basic auth; legacy bearer tokens
            # (ATCTT3x...) continue supported for compatibility.
            self.use_bearer = api_token.startswith("ATCTT3x")

        # Pre-compute auth kwargs for all httpx calls
        if self.use_bearer:
            self._auth_kwargs = {"headers": {"Authorization": f"Bearer {self.api_token}"}}
        else:
            self._auth_kwargs = {"auth": (self.auth_user, self.api_token)}

    def _configure_repo(self, repo_slug: Optional[str], auth_hint: str) -> None:
        """Resolve repo slug and set base URL / metadata.

        Args:
            repo_slug: Explicit slug or None for auto-detection.
            auth_hint: Human-readable hint shown in error messages.
        """
        self.repo_slug = (
            repo_slug
            or os.getenv("BITBUCKET_REPO_SLUG")
            or self._get_repo_slug()
        )
        self.base_url = f"https://api.bitbucket.org/2.0/repositories/{self.repo_slug}"
        self._provider_name = "Bitbucket"
        self._auth_hint = auth_hint
        # Rate limiter: 1000 requests per hour (Bitbucket Cloud API limit)
        self.rate_limiter = AsyncLimiter(max_rate=1000, time_period=3600)

    # ------------------------------------------------------------------
    # Constructors
    # ------------------------------------------------------------------

    def __init__(self, repo_slug: Optional[str] = None):
        """
        Initialize the Bitbucket Pipeline client

        Args:
            repo_slug: Optional repo slug override (format: workspace/repo-name).
                       If not provided, uses BITBUCKET_REPO_SLUG env var or
                       auto-detects from git remote.

        Raises:
            ValueError: If required environment variables are missing or
                       if repository slug cannot be determined
        """
        # Shared principal resolution order:
        # BITBUCKET_EMAIL -> JIRA_EMAIL -> BITBUCKET_USERNAME
        auth_user = (
            os.getenv("BITBUCKET_EMAIL")
            or os.getenv("JIRA_EMAIL")
            or os.getenv("BITBUCKET_USERNAME")
        )
        api_token = os.getenv("BITBUCKET_API_TOKEN") or os.getenv("BITBUCKET_APP_PASSWORD")

        if not api_token:
            raise ValueError(
                "Missing required credentials. "
                "Please set BITBUCKET_API_TOKEN environment variable "
                "(legacy fallback: BITBUCKET_APP_PASSWORD)."
            )

        self._configure_auth(
            auth_user=auth_user,
            api_token=api_token,
            auth_type=os.getenv("BITBUCKET_AUTH_TYPE", ""),
        )

        if not self.use_bearer and not self.auth_user:
            raise ValueError(
                "Missing Basic-auth principal. "
                "Set BITBUCKET_EMAIL (preferred), JIRA_EMAIL (shared fallback), "
                "or BITBUCKET_USERNAME; "
                "or set BITBUCKET_AUTH_TYPE=bearer for token-only auth."
            )

        self._configure_repo(
            repo_slug=repo_slug,
            auth_hint=(
                "Verifique BITBUCKET_API_TOKEN e (quando auth basic) "
                "BITBUCKET_EMAIL/JIRA_EMAIL/BITBUCKET_USERNAME."
            ),
        )

    @staticmethod
    def validate_account_id(account_id: str) -> str:
        """Normalize and validate an account identifier.

        The account_id is used to construct env-var names
        (``BITBUCKET_ACCOUNT_{ID}_*``), so it must only contain characters
        that are safe for that purpose: lowercase alphanumeric, hyphens,
        and underscores.

        Args:
            account_id: Raw account identifier supplied by the caller.

        Returns:
            Normalized (stripped + lowercased) account_id.

        Raises:
            ValueError: If the account_id contains invalid characters.
        """
        normalized = account_id.strip().lower()
        if not _VALID_ACCOUNT_ID_RE.match(normalized):
            raise ValueError(
                f"Invalid account_id '{account_id}'. "
                "Only lowercase alphanumeric characters, hyphens, and "
                "underscores are allowed (must start with alphanumeric)."
            )
        return normalized

    @classmethod
    def for_account(cls, account_id: str, repo_slug: Optional[str] = None) -> "BitbucketPipelineClient":
        """
        Create a client using credentials from a named account.

        Reads BITBUCKET_ACCOUNT_{ID}_* env vars for per-account credentials.
        Falls back to the default client if the account is "default" or empty.

        Env vars read (where PREFIX = BITBUCKET_ACCOUNT_{UPPER_ID}_):
            {PREFIX}USERNAME or {PREFIX}EMAIL  — Basic auth principal
            {PREFIX}APP_PASSWORD or {PREFIX}API_TOKEN  — credential
            {PREFIX}AUTH_TYPE  — "basic" or "bearer" (falls back to global)
        """
        if not account_id or account_id.strip().lower() == "default":
            return cls(repo_slug=repo_slug)

        account_id = cls.validate_account_id(account_id)
        prefix = f"BITBUCKET_ACCOUNT_{account_id.upper()}_"

        token = os.getenv(f"{prefix}APP_PASSWORD") or os.getenv(f"{prefix}API_TOKEN")
        if not token:
            raise ValueError(
                f"No credentials found for account '{account_id}'. "
                f"Set {prefix}APP_PASSWORD or {prefix}API_TOKEN."
            )

        user = (
            os.getenv(f"{prefix}USERNAME")
            or os.getenv(f"{prefix}EMAIL")
        )

        auth_type = os.getenv(f"{prefix}AUTH_TYPE", "")
        if not auth_type.strip():
            auth_type = os.getenv("BITBUCKET_AUTH_TYPE", "")

        instance = cls.__new__(cls)
        instance._configure_auth(auth_user=user, api_token=token, auth_type=auth_type)

        if not instance.use_bearer and not instance.auth_user:
            raise ValueError(
                f"Account '{account_id}' uses Basic auth but no principal set. "
                f"Set {prefix}USERNAME or {prefix}EMAIL."
            )

        instance._configure_repo(
            repo_slug=repo_slug,
            auth_hint=f"Account '{account_id}' credentials.",
        )

        return instance

    def _get_repo_slug(self) -> str:
        """
        Extract repository slug (workspace/repo-name) from git remote URL

        Returns:
            str: Repository slug in format "workspace/repo-name"

        Raises:
            ValueError: If git remote URL cannot be parsed
        """
        try:
            result = subprocess.run(
                ["git", "config", "--get", "remote.origin.url"],
                capture_output=True,
                text=True,
                check=True,
                timeout=5,
            )
            url = result.stdout.strip()

            if not url:
                raise ValueError("Git remote URL is empty")

            # Parse both HTTPS and SSH formats:
            # https://bitbucket.org/workspace/repo.git
            # git@bitbucket.org:workspace/repo.git
            match = re.search(r"bitbucket\.org[/:](.+?)\.git$", url)

            if match:
                return match.group(1)
            else:
                raise ValueError(
                    f"Cannot parse Bitbucket repository slug from URL: {url}. "
                    "Pass repo_slug in the tool call or set BITBUCKET_REPO_SLUG."
                )

        except subprocess.CalledProcessError as e:
            raise ValueError(
                f"Failed to get git remote URL: {e.stderr.strip()}. "
                "Pass repo_slug in the tool call or set BITBUCKET_REPO_SLUG."
            ) from e
        except subprocess.TimeoutExpired:
            raise ValueError(
                "Git command timed out. Pass repo_slug in the tool call or set BITBUCKET_REPO_SLUG."
            ) from None

    async def get_pipelines(
        self, sort: str = "-created_on", pagelen: int = 25
    ) -> dict:
        """
        Get paginated list of pipelines

        Args:
            sort: Sort order (default: "-created_on" for newest first)
            pagelen: Number of results per page (default: 25, max: 100)

        Returns:
            dict: Bitbucket API response with 'values' array and pagination info

        Raises:
            ApiError: If API request fails (auth/not-found/rate-limit/server/network)
        """
        return await request_json(
            method="GET",
            url=f"{self.base_url}/pipelines",
            provider=self._provider_name,
            auth_hint=self._auth_hint,
            auth_kwargs=self._auth_kwargs,
            params={"sort": sort, "pagelen": pagelen},
            timeout=30.0,
            limiter=self.rate_limiter,
        )

    async def get_pipeline(self, build_number: int) -> dict:
        """
        Get detailed information about a specific pipeline

        Args:
            build_number: Build number to query

        Returns:
            dict: Pipeline object with full details

        Raises:
            ApiError: If API request fails (auth/not-found/rate-limit/server/network)
        """
        return await request_json(
            method="GET",
            url=f"{self.base_url}/pipelines/{build_number}",
            provider=self._provider_name,
            auth_hint=self._auth_hint,
            auth_kwargs=self._auth_kwargs,
            timeout=30.0,
            limiter=self.rate_limiter,
        )

    async def get_pipeline_steps(self, build_number: int) -> dict:
        """
        Get all steps for a specific pipeline

        Args:
            build_number: Build number to query

        Returns:
            dict: Response with 'values' array of step objects

        Raises:
            ApiError: If API request fails (auth/not-found/rate-limit/server/network)
        """
        return await request_json(
            method="GET",
            url=f"{self.base_url}/pipelines/{build_number}/steps/",
            provider=self._provider_name,
            auth_hint=self._auth_hint,
            auth_kwargs=self._auth_kwargs,
            timeout=30.0,
            limiter=self.rate_limiter,
        )

    async def get_step_log(self, build_number: int, step_uuid: str) -> str:
        """
        Get log output for a specific step

        Args:
            build_number: Build number
            step_uuid: Step UUID (with or without curly braces)

        Returns:
            str: Raw log output (plain text)

        Raises:
            ApiError: If API request fails (auth/not-found/rate-limit/server/network)
        """
        # Ensure UUID has curly braces (API requires them)
        if not step_uuid.startswith("{"):
            step_uuid = f"{{{step_uuid}}}"

        # URL-encode the UUID (curly braces become %7B and %7D)
        # This is required by Bitbucket API
        step_uuid_encoded = quote(step_uuid, safe="")

        return await request_text(
            method="GET",
            url=f"{self.base_url}/pipelines/{build_number}/steps/{step_uuid_encoded}/log",
            provider=self._provider_name,
            auth_hint=self._auth_hint,
            auth_kwargs=self._auth_kwargs,
            timeout=60.0,
            follow_redirects=True,
            limiter=self.rate_limiter,
        )

    async def get_step_logs(self, build_number: int, step_name: str) -> dict:
        """
        Get log output for a specific step by name (helper method for Sprint 6)

        This is a convenience method that finds the step UUID by name and then
        retrieves the logs. Used by diagnose_pipeline_failure.

        Args:
            build_number: Build number
            step_name: Step name (e.g., "Build and Test")

        Returns:
            dict: {"logs": "raw log text", "step_uuid": "{uuid}"}

        Raises:
            ValueError: If step name not found
            ApiError: If API request fails (auth/not-found/rate-limit/server/network)
        """
        # Get all steps for this build
        steps_data = await self.get_pipeline_steps(build_number)

        # Find step by name
        step_uuid = None
        for step in steps_data.get("values", []):
            if step.get("name") == step_name:
                step_uuid = step.get("uuid")
                break

        if not step_uuid:
            raise ValueError(f"Step '{step_name}' not found in build {build_number}")

        # Get logs using UUID
        logs = await self.get_step_log(build_number, step_uuid)

        return {
            "logs": logs,
            "step_uuid": step_uuid,
            "step_name": step_name
        }

    async def get_test_reports(self, build_number: int, step_uuid: str) -> dict:
        """
        Get test report summary for a specific step

        Args:
            build_number: Build number
            step_uuid: Step UUID (with or without curly braces)

        Returns:
            dict: Test report summary with counts and duration
                  Format: {
                      "page": 1,
                      "values": [
                          {
                              "uuid": "{report-uuid}",
                              "test_count": 15,
                              "successful_test_count": 12,
                              "failed_test_count": 3,
                              "skipped_test_count": 0,
                              "duration": 45.2
                          }
                      ]
                  }

        Raises:
            httpx.HTTPError: If API request fails (404 if no test reports available)
        """
        # Ensure UUID has curly braces (API requires them)
        if not step_uuid.startswith("{"):
            step_uuid = f"{{{step_uuid}}}"

        # URL-encode the UUID (curly braces become %7B and %7D)
        step_uuid_encoded = quote(step_uuid, safe="")

        async with self.rate_limiter:
            async with httpx.AsyncClient(timeout=60.0, follow_redirects=True) as client:
                response = await client.get(
                    f"{self.base_url}/pipelines/{build_number}/steps/{step_uuid_encoded}/test_reports",
                    **self._auth_kwargs,
                )
                response.raise_for_status()
                return response.json()

    async def get_test_cases(
        self, build_number: int, step_uuid: str
    ) -> dict:
        """
        Get test cases for a specific step

        Args:
            build_number: Build number
            step_uuid: Step UUID (with or without curly braces)

        Returns:
            dict: List of test cases
                  Format: {
                      "page": 1,
                      "values": [
                          {
                              "uuid": "{test-case-uuid}",
                              "name": "test_user_authentication",
                              "class_name": "TestUserAuth",
                              "duration": 2.3,
                              "status": "FAILED"
                          }
                      ]
                  }

        Raises:
            httpx.HTTPError: If API request fails
        """
        # Ensure UUID has curly braces (API requires them)
        if not step_uuid.startswith("{"):
            step_uuid = f"{{{step_uuid}}}"

        # URL-encode the UUID
        step_uuid_encoded = quote(step_uuid, safe="")

        async with self.rate_limiter:
            async with httpx.AsyncClient(timeout=60.0, follow_redirects=True) as client:
                response = await client.get(
                    f"{self.base_url}/pipelines/{build_number}/steps/{step_uuid_encoded}/test_reports/test_cases",
                    **self._auth_kwargs,
                )
                response.raise_for_status()
                return response.json()

    async def get_test_case_reasons(
        self, build_number: int, step_uuid: str, test_case_uuid: str
    ) -> dict:
        """
        Get failure reasons (stack trace/output) for a specific test case

        Args:
            build_number: Build number
            step_uuid: Step UUID (with or without curly braces)
            test_case_uuid: Test case UUID (with or without curly braces)

        Returns:
            dict: Failure reasons with message and stack trace
                  Format: {
                      "page": 1,
                      "values": [
                          {
                              "message": "AssertionError: Expected status 200, got 401",
                              "stack_trace": "Traceback...",
                              "type": "FAILURE"
                          }
                      ]
                  }

        Raises:
            httpx.HTTPError: If API request fails
        """
        # Ensure UUIDs have curly braces (API requires them)
        if not step_uuid.startswith("{"):
            step_uuid = f"{{{step_uuid}}}"
        if not test_case_uuid.startswith("{"):
            test_case_uuid = f"{{{test_case_uuid}}}"

        # URL-encode both UUIDs
        step_uuid_encoded = quote(step_uuid, safe="")
        test_case_uuid_encoded = quote(test_case_uuid, safe="")

        async with self.rate_limiter:
            async with httpx.AsyncClient(timeout=60.0, follow_redirects=True) as client:
                response = await client.get(
                    f"{self.base_url}/pipelines/{build_number}/steps/{step_uuid_encoded}/test_reports/test_cases/{test_case_uuid_encoded}/test_case_reasons",
                    **self._auth_kwargs,
                )
                response.raise_for_status()
                return response.json()

    # ========================================================================
    # Deployments API (Sprint 2)
    # ========================================================================

    async def get_deployments(
        self, environment: Optional[str] = None, pagelen: int = 10
    ) -> dict:
        """
        Get recent deployments for the repository

        Args:
            environment: Filter by environment name (e.g., "Production", "Staging")
            pagelen: Number of results per page (default: 10)

        Returns:
            dict: Paginated list of deployments
                  Format: {
                      "page": 1,
                      "pagelen": 10,
                      "values": [
                          {
                              "uuid": "{deployment-uuid}",
                              "state": {"name": "COMPLETED", "status": {"name": "SUCCESSFUL"}},
                              "deployable": {"uuid": "{pipeline-uuid}"},
                              "environment": {"name": "Production"},
                              "release": {"name": "v1.2.3"},
                              "created_on": "2025-10-31T10:00:00.000000+00:00",
                              "completed_on": "2025-10-31T10:05:30.000000+00:00"
                          }
                      ]
                  }

        Raises:
            httpx.HTTPError: If API request fails
        """
        params = {"pagelen": pagelen}

        async with self.rate_limiter:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.get(
                    f"{self.base_url}/deployments",
                    **self._auth_kwargs,
                    params=params,
                )
                response.raise_for_status()
                data = response.json()

                # Filter by environment if specified (client-side)
                if environment:
                    filtered_values = [
                        d
                        for d in data.get("values", [])
                        if d.get("environment", {}).get("name") == environment
                    ]
                    data["values"] = filtered_values
                    data["size"] = len(filtered_values)

                return data

    async def get_deployment(self, deployment_uuid: str) -> dict:
        """
        Get details of a specific deployment

        Args:
            deployment_uuid: Deployment UUID (with or without curly braces)

        Returns:
            dict: Deployment details
                  Format: {
                      "uuid": "{deployment-uuid}",
                      "state": {"name": "COMPLETED"},
                      "environment": {"name": "Production", "uuid": "{env-uuid}"},
                      "deployable": {"uuid": "{pipeline-uuid}", "type": "pipeline"},
                      "release": {"name": "v1.2.3"},
                      "created_on": "2025-10-31T10:00:00.000000+00:00",
                      "completed_on": "2025-10-31T10:05:30.000000+00:00"
                  }

        Raises:
            httpx.HTTPError: If API request fails
        """
        # Ensure UUID has curly braces
        if not deployment_uuid.startswith("{"):
            deployment_uuid = f"{{{deployment_uuid}}}"

        # URL-encode the UUID
        deployment_uuid_encoded = quote(deployment_uuid, safe="")

        async with self.rate_limiter:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.get(
                    f"{self.base_url}/deployments/{deployment_uuid_encoded}",
                    **self._auth_kwargs,
                )
                response.raise_for_status()
                return response.json()

    # ========================================================================
    # Environments & Variables API (Sprint 2)
    # ========================================================================

    async def get_environments(self) -> dict:
        """
        Get all deployment environments configured for the repository

        Returns:
            dict: Paginated list of environments
                  Format: {
                      "page": 1,
                      "values": [
                          {
                              "uuid": "{env-uuid}",
                              "name": "Production",
                              "slug": "production",
                              "type": "Production",
                              "rank": 1,
                              "environment_type": {"name": "Production", "rank": 1}
                          }
                      ]
                  }

        Raises:
            httpx.HTTPError: If API request fails
        """
        async with self.rate_limiter:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.get(
                    f"{self.base_url}/environments",
                    **self._auth_kwargs,
                )
                response.raise_for_status()
                return response.json()

    async def get_environment_variables(self, environment_uuid: str) -> dict:
        """
        Get all variables for a specific environment

        Args:
            environment_uuid: Environment UUID (with or without curly braces)

        Returns:
            dict: Paginated list of environment variables
                  Format: {
                      "page": 1,
                      "values": [
                          {
                              "uuid": "{var-uuid}",
                              "key": "APP_ENDPOINT",
                              "value": "https://api.example.com",  # Only if not secured
                              "secured": false,
                              "type": "pipeline_variable"
                          }
                      ]
                  }

        Note:
            Secured variables will not return the "value" field (Bitbucket security policy)

        Raises:
            httpx.HTTPError: If API request fails
        """
        # Ensure UUID has curly braces
        if not environment_uuid.startswith("{"):
            environment_uuid = f"{{{environment_uuid}}}"

        # URL-encode the UUID
        environment_uuid_encoded = quote(environment_uuid, safe="")

        async with self.rate_limiter:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.get(
                    f"{self.base_url}/deployments_config/environments/{environment_uuid_encoded}/variables",
                    **self._auth_kwargs,
                )
                response.raise_for_status()
                return response.json()

    async def get_repository_variables(self) -> dict:
        """
        Get all pipeline variables configured at repository level

        Returns:
            dict: Paginated list of repository variables
                  Format: {
                      "page": 1,
                      "values": [
                          {
                              "uuid": "{var-uuid}",
                              "key": "MY_REPO_ID",
                              "value": "my-repo",  # Only if not secured
                              "secured": false,
                              "type": "pipeline_variable"
                          }
                      ]
                  }

        Note:
            Secured variables will not return the "value" field (Bitbucket security policy)

        Raises:
            httpx.HTTPError: If API request fails
        """
        async with self.rate_limiter:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.get(
                    f"{self.base_url}/pipelines_config/variables",
                    **self._auth_kwargs,
                )
                response.raise_for_status()
                return response.json()

    async def create_repository_variable(
        self, key: str, value: str, secured: bool = False
    ) -> dict:
        """
        Create or update a pipeline variable at repository level

        Args:
            key: Variable name (e.g., "AWS_OIDC_ROLE_ARN")
            value: Variable value
            secured: If True, value is encrypted and hidden in UI/API reads

        Returns:
            dict: Created variable details

        Raises:
            httpx.HTTPError: If API request fails
        """
        async with self.rate_limiter:
            async with httpx.AsyncClient(timeout=30.0) as client:
                # Check if variable already exists
                existing = await self.get_repository_variables()
                existing_var = next(
                    (v for v in existing.get("values", []) if v.get("key") == key),
                    None,
                )

                payload = {"key": key, "value": value, "secured": secured}

                if existing_var:
                    # Update existing variable
                    var_uuid = existing_var["uuid"]
                    response = await client.put(
                        f"{self.base_url}/pipelines_config/variables/{var_uuid}",
                        json=payload,
                        **self._auth_kwargs,
                    )
                else:
                    # Create new variable
                    response = await client.post(
                        f"{self.base_url}/pipelines_config/variables/",
                        json=payload,
                        **self._auth_kwargs,
                    )

                response.raise_for_status()
                return response.json()

    async def delete_repository_variable(self, key: str) -> dict:
        """
        Delete a pipeline variable at repository level

        Args:
            key: Variable name to delete

        Returns:
            dict: Deletion confirmation

        Raises:
            httpx.HTTPError: If API request fails
            ValueError: If variable not found
        """
        async with self.rate_limiter:
            async with httpx.AsyncClient(timeout=30.0) as client:
                existing = await self.get_repository_variables()
                existing_var = next(
                    (v for v in existing.get("values", []) if v.get("key") == key),
                    None,
                )

                if not existing_var:
                    raise ValueError(f"Variable '{key}' not found in repository")

                var_uuid = existing_var["uuid"]
                response = await client.delete(
                    f"{self.base_url}/pipelines_config/variables/{var_uuid}",
                    **self._auth_kwargs,
                )
                response.raise_for_status()
                return {"deleted": key, "uuid": var_uuid}

    async def get_workspace_variables(self) -> dict:
        """
        Get all pipeline variables configured at workspace level

        Returns:
            dict: Paginated list of workspace variables
                  Format: {
                      "page": 1,
                      "values": [
                          {
                              "uuid": "{var-uuid}",
                              "key": "MY_WORKSPACE_ID",
                              "value": "my-workspace",  # Only if not secured
                              "secured": false,
                              "type": "pipeline_variable"
                          }
                      ]
                  }

        Note:
            Secured variables will not return the "value" field (Bitbucket security policy)
            Workspace slug is extracted from repo_slug

        Raises:
            httpx.HTTPError: If API request fails
        """
        # Extract workspace slug from repo_slug (format: "workspace/repo")
        workspace = self.repo_slug.split("/")[0]

        async with self.rate_limiter:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.get(
                    f"https://api.bitbucket.org/2.0/workspaces/{workspace}/pipelines-config/variables",
                    **self._auth_kwargs,
                )
                response.raise_for_status()
                return response.json()

    # ========================================================================
    # Cache Management API (Sprint 3)
    # ========================================================================

    async def get_caches(self) -> dict:
        """
        Get all configured pipeline caches for the repository

        Returns:
            dict: List of configured caches
                  Format: {
                      "page": 1,
                      "values": [
                          {
                              "name": "maven",
                              "path": "~/.m2/repository",
                              "enabled": true
                          },
                          {
                              "name": "gradle",
                              "path": "~/.gradle/caches",
                              "enabled": true
                          }
                      ]
                  }

        Note:
            Returns configured caches from bitbucket-pipelines.yml definitions section

        Raises:
            httpx.HTTPError: If API request fails
        """
        async with self.rate_limiter:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.get(
                    f"{self.base_url}/pipelines-config/caches",
                    **self._auth_kwargs,
                )
                response.raise_for_status()
                return response.json()

    async def get_cache_content_uri(self, cache_name: str) -> dict:
        """
        Get content URI for a specific cache (for download/inspection)

        Args:
            cache_name: Name of the cache (e.g., "maven", "gradle", "node")

        Returns:
            dict: Cache content URI and metadata
                  Format: {
                      "name": "maven",
                      "size": 182428672,  # bytes
                      "content_uri": "https://...",
                      "created_on": "2025-10-30T10:00:00.000000+00:00"
                  }

        Note:
            Cache must exist and have been used at least once to have content

        Raises:
            httpx.HTTPError: If API request fails (404 if cache not used yet)
        """
        async with self.rate_limiter:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.get(
                    f"{self.base_url}/pipelines-config/caches/{cache_name}/content-uri",
                    **self._auth_kwargs,
                )
                response.raise_for_status()
                return response.json()

    async def delete_cache(self, cache_name: str) -> dict:
        """
        Delete (clear) a specific pipeline cache

        Args:
            cache_name: Name of the cache to clear (e.g., "maven", "gradle")

        Returns:
            dict: Success confirmation or error details
                  Format: {
                      "status": "deleted",
                      "cache_name": "maven",
                      "message": "Cache cleared successfully"
                  }

        Note:
            - Requires write permissions on repository
            - Cache definition remains in bitbucket-pipelines.yml
            - Only clears cached content, not configuration
            - Next build will recreate cache from scratch

        Raises:
            httpx.HTTPError: If API request fails or insufficient permissions
        """
        async with self.rate_limiter:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.delete(
                    f"{self.base_url}/pipelines-config/caches/{cache_name}",
                    **self._auth_kwargs,
                )
                response.raise_for_status()

                # DELETE typically returns 204 No Content on success
                if response.status_code == 204:
                    return {
                        "status": "deleted",
                        "cache_name": cache_name,
                        "message": "Cache cleared successfully",
                    }
                return response.json()

    # ========================================================================
    # Commits & Build Status API (Sprint 4)
    # ========================================================================

    async def get_commit(self, commit_hash: str) -> dict:
        """
        Get details about a specific commit

        Args:
            commit_hash: Commit hash (full or short)

        Returns:
            dict: Commit details
                  Format: {
                      "hash": "16dbb13e...",
                      "date": "2025-10-31T10:00:00+00:00",
                      "author": {
                          "raw": "John Doe <john@example.com>",
                          "user": {...}
                      },
                      "message": "Commit message",
                      "parents": [{"hash": "..."}],
                      "summary": {"raw": "..."}
                  }

        Raises:
            httpx.HTTPError: If API request fails (404 if commit not found)
        """
        async with self.rate_limiter:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.get(
                    f"{self.base_url}/commit/{commit_hash}",
                    **self._auth_kwargs,
                )
                response.raise_for_status()
                return response.json()

    async def get_commit_statuses(self, commit_hash: str, pagelen: int = 50) -> dict:
        """
        Get all build statuses for a specific commit

        This includes both Bitbucket Pipelines builds and external CI/CD systems
        (Jenkins, CircleCI, etc.) that report status to Bitbucket.

        Args:
            commit_hash: Commit hash (full or short)
            pagelen: Number of statuses per page (default 50, max 100)

        Returns:
            dict: Build statuses
                  Format: {
                      "size": 3,
                      "page": 1,
                      "values": [
                          {
                              "type": "build",
                              "key": "PIPELINE",
                              "name": "Pipeline #640",
                              "state": "SUCCESSFUL",
                              "url": "https://...",
                              "description": "Build succeeded",
                              "created_on": "2025-10-31T10:00:00+00:00",
                              "updated_on": "2025-10-31T10:05:00+00:00"
                          }
                      ]
                  }

        Note:
            - state values: SUCCESSFUL, FAILED, INPROGRESS, STOPPED
            - External CI systems can also report statuses here
            - Empty list if no builds triggered for commit

        Raises:
            httpx.HTTPError: If API request fails (404 if commit not found)
        """
        async with self.rate_limiter:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.get(
                    f"{self.base_url}/commit/{commit_hash}/statuses",
                    params={"pagelen": pagelen},
                    **self._auth_kwargs,
                )
                response.raise_for_status()
                return response.json()

    # ========================================================================
    # Pull Requests & Configuration API (Sprint 5)
    # ========================================================================

    async def get_pull_requests(
        self, state: str = "OPEN", pagelen: int = 50
    ) -> dict:
        """
        Get pull requests for the repository

        Args:
            state: PR state filter (OPEN, MERGED, DECLINED, SUPERSEDED)
            pagelen: Number of PRs per page (default 50, max 100)

        Returns:
            dict: Pull requests list
                  Format: {
                      "size": 10,
                      "page": 1,
                      "values": [
                          {
                              "id": 123,
                              "title": "Feature X",
                              "state": "OPEN",
                              "author": {...},
                              "source": {"branch": {"name": "feature/x"}},
                              "destination": {"branch": {"name": "develop"}},
                              "created_on": "2025-10-31T10:00:00+00:00",
                              "updated_on": "2025-10-31T11:00:00+00:00"
                          }
                      ]
                  }

        Raises:
            ApiError: If API request fails (auth/not-found/rate-limit/server/network)
        """
        return await request_json(
            method="GET",
            url=f"{self.base_url}/pullrequests",
            provider=self._provider_name,
            auth_hint=self._auth_hint,
            auth_kwargs=self._auth_kwargs,
            params={"state": state, "pagelen": pagelen},
            timeout=30.0,
            limiter=self.rate_limiter,
        )

    async def get_pull_request(self, pr_id: int) -> dict:
        """
        Get details about a specific pull request

        Args:
            pr_id: Pull request ID

        Returns:
            dict: Pull request details
                  Format: {
                      "id": 123,
                      "title": "Feature X",
                      "description": "...",
                      "state": "OPEN",
                      "author": {...},
                      "reviewers": [...],
                      "participants": [...],
                      "source": {"branch": {...}, "commit": {...}},
                      "destination": {"branch": {...}, "commit": {...}},
                      "merge_commit": {...},
                      "links": {...}
                  }

        Raises:
            ApiError: If API request fails (auth/not-found/rate-limit/server/network)
        """
        return await request_json(
            method="GET",
            url=f"{self.base_url}/pullrequests/{pr_id}",
            provider=self._provider_name,
            auth_hint=self._auth_hint,
            auth_kwargs=self._auth_kwargs,
            timeout=30.0,
            limiter=self.rate_limiter,
        )

    async def get_pr_statuses(self, pr_id: int, pagelen: int = 50) -> dict:
        """
        Get all build statuses for a specific pull request

        Args:
            pr_id: Pull request ID
            pagelen: Number of statuses per page (default 50, max 100)

        Returns:
            dict: Build statuses for the PR
                  Format: {
                      "size": 3,
                      "page": 1,
                      "values": [
                          {
                              "type": "build",
                              "key": "PIPELINE",
                              "name": "Pipeline #640",
                              "state": "SUCCESSFUL",
                              "url": "https://...",
                              "description": "Build succeeded",
                              "created_on": "2025-10-31T10:00:00+00:00"
                          }
                      ]
                  }

        Raises:
            ApiError: If API request fails (auth/not-found/rate-limit/server/network)
        """
        return await request_json(
            method="GET",
            url=f"{self.base_url}/pullrequests/{pr_id}/statuses",
            provider=self._provider_name,
            auth_hint=self._auth_hint,
            auth_kwargs=self._auth_kwargs,
            params={"pagelen": pagelen},
            timeout=30.0,
            limiter=self.rate_limiter,
        )

    async def get_pr_comments(self, pr_id: int, pagelen: int = 50) -> dict:
        """
        Get all comments for a specific pull request

        Args:
            pr_id: Pull request ID
            pagelen: Page length

        Returns:
            dict: Comments for the pull request
        """
        return await request_json(
            method="GET",
            url=f"{self.base_url}/pullrequests/{pr_id}/comments",
            provider=self._provider_name,
            auth_hint=self._auth_hint,
            auth_kwargs=self._auth_kwargs,
            params={"pagelen": pagelen},
            timeout=30.0,
            limiter=self.rate_limiter,
        )

    async def merge_pull_request(self, pr_id: int) -> dict:
        """
        Merge a specific pull request

        Args:
            pr_id: Pull request ID

        Returns:
            dict: PR details after merge
        """
        return await request_json(
            method="POST",
            url=f"{self.base_url}/pullrequests/{pr_id}/merge",
            provider=self._provider_name,
            auth_hint=self._auth_hint,
            auth_kwargs=self._auth_kwargs,
            timeout=30.0,
            limiter=self.rate_limiter,
        )

    async def approve_pull_request(self, pr_id: int) -> dict:
        """
        Approve a pull request as the authenticated user

        The approval is registered under the identity of the token owner.
        This is useful when the MCP hub runs with a service account token,
        allowing it to act as a separate reviewer/approver.

        Bitbucket API: POST /2.0/repositories/{workspace}/{repo}/pullrequests/{id}/approve

        Args:
            pr_id: Pull request ID

        Returns:
            dict: Approval details
                  Format: {
                      "approved": true,
                      "user": {
                          "display_name": "Bot User",
                          "uuid": "{...}"
                      },
                      "role": "PARTICIPANT",
                      "state": "approved"
                  }

        Raises:
            ApiError: If API request fails (409 if already approved)
        """
        return await request_json(
            method="POST",
            url=f"{self.base_url}/pullrequests/{pr_id}/approve",
            provider=self._provider_name,
            auth_hint=self._auth_hint,
            auth_kwargs=self._auth_kwargs,
            timeout=30.0,
            limiter=self.rate_limiter,
        )

    async def unapprove_pull_request(self, pr_id: int) -> dict:
        """
        Remove approval from a pull request

        Args:
            pr_id: Pull request ID

        Returns:
            dict: Empty response on success (HTTP 204)

        Raises:
            ApiError: If API request fails
        """
        return await request_json(
            method="DELETE",
            url=f"{self.base_url}/pullrequests/{pr_id}/approve",
            provider=self._provider_name,
            auth_hint=self._auth_hint,
            auth_kwargs=self._auth_kwargs,
            timeout=30.0,
            limiter=self.rate_limiter,
        )

    async def create_pull_request(
        self,
        title: str,
        source_branch: str,
        destination_branch: str,
        description: str = "",
        close_source_branch: bool = False,
        reviewers: list = None
    ) -> dict:
        """
        Create a new pull request

        Args:
            title: PR title
            source_branch: Source branch name
            destination_branch: Destination branch name
            description: PR description (optional)
            close_source_branch: Whether to close source branch on merge (default: False)
            reviewers: List of reviewer UUIDs (optional)

        Returns:
            dict: Created pull request details
                  Format: {
                      "id": 123,
                      "title": "...",
                      "state": "OPEN",
                      "links": {
                          "html": {"href": "https://..."}
                      },
                      ...
                  }

        Raises:
            ApiError: If API request fails (auth/not-found/rate-limit/server/network)
        """
        payload = {
            "title": title,
            "source": {
                "branch": {
                    "name": source_branch
                }
            },
            "destination": {
                "branch": {
                    "name": destination_branch
                }
            },
            "close_source_branch": close_source_branch
        }

        if description:
            payload["description"] = description

        if reviewers:
            payload["reviewers"] = [{"uuid": uuid} for uuid in reviewers]

        return await request_json(
            method="POST",
            url=f"{self.base_url}/pullrequests",
            provider=self._provider_name,
            auth_hint=self._auth_hint,
            auth_kwargs=self._auth_kwargs,
            json=payload,
            timeout=30.0,
            limiter=self.rate_limiter,
            max_retries=0,  # non-idempotent operation: avoid duplicate PR creation
        )

    async def get_pipeline_schedules(self) -> dict:
        """
        Get configured pipeline schedules (cron-based triggers)

        Returns:
            dict: Pipeline schedules
                  Format: {
                      "size": 2,
                      "page": 1,
                      "values": [
                          {
                              "uuid": "{...}",
                              "type": "pipeline_schedule",
                              "enabled": true,
                              "target": {
                                  "ref_type": "branch",
                                  "ref_name": "develop"
                              },
                              "cron_pattern": "0 2 * * *",
                              "created_on": "2025-10-01T10:00:00+00:00"
                          }
                      ]
                  }

        Note:
            Returns empty list if no schedules configured

        Raises:
            httpx.HTTPError: If API request fails
        """
        async with self.rate_limiter:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.get(
                    f"{self.base_url}/pipelines-config/schedules",
                    **self._auth_kwargs,
                )
                response.raise_for_status()
                return response.json()

    async def get_pipeline_configuration(self) -> dict:
        """
        Get repository pipeline configuration

        Returns:
            dict: Pipeline configuration
                  Format: {
                      "enabled": true,
                      "type": "pipelines",
                      "repository": {...},
                      "has_pipelines": true
                  }

        Raises:
            httpx.HTTPError: If API request fails
        """
        async with self.rate_limiter:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.get(
                    f"{self.base_url}/pipelines-config",
                    **self._auth_kwargs,
                )
                response.raise_for_status()
                return response.json()

    async def get_pipeline_ssh_keys(self) -> dict:
        """
        Get pipeline SSH key pair configuration

        Returns:
            dict: SSH key pair
                  Format: {
                      "type": "pipeline_ssh_key_pair",
                      "public_key": "ssh-rsa AAAA...",
                      "private_key_sha256": "SHA256:...",
                  }

        Note:
            Private key is never returned, only SHA256 fingerprint
            Returns 404 if no SSH key configured

        Raises:
            httpx.HTTPError: If API request fails (404 if not configured)
        """
        async with self.rate_limiter:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.get(
                    f"{self.base_url}/pipelines-config/ssh/key_pair",
                    **self._auth_kwargs,
                )
                response.raise_for_status()
                return response.json()

    # ========================================================================
    # Pipeline Trigger & Control API (Sprint 7)
    # ========================================================================

    async def trigger_pipeline(
        self,
        ref_name: str,
        custom_pipeline: Optional[str] = None,
        variables: Optional[list] = None,
    ) -> dict:
        """
        Trigger a pipeline on a branch, optionally selecting a custom pipeline

        Args:
            ref_name: Branch name to run the pipeline on
            custom_pipeline: Custom pipeline name from bitbucket-pipelines.yml (optional)
            variables: List of variable dicts [{"key": "K", "value": "V", "secured": False}]

        Returns:
            dict: Created pipeline object with build_number, uuid, state

        Raises:
            httpx.HTTPError: If API request fails (e.g., 400 if pipeline not found)
        """
        payload = {
            "target": {
                "ref_type": "branch",
                "type": "pipeline_ref_target",
                "ref_name": ref_name,
            }
        }

        if custom_pipeline:
            payload["target"]["selector"] = {
                "type": "custom",
                "pattern": custom_pipeline,
            }

        if variables:
            payload["variables"] = variables

        async with self.rate_limiter:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(
                    f"{self.base_url}/pipelines/",
                    json=payload,
                    **self._auth_kwargs,
                )
                response.raise_for_status()
                return response.json()

    async def stop_pipeline(self, pipeline_uuid: str) -> dict:
        """
        Stop a running pipeline

        Args:
            pipeline_uuid: Pipeline UUID (with or without curly braces)

        Returns:
            dict: {"status": "stopped", "pipeline_uuid": "..."}

        Raises:
            httpx.HTTPError: If API request fails
        """
        if not pipeline_uuid.startswith("{"):
            pipeline_uuid = f"{{{pipeline_uuid}}}"

        pipeline_uuid_encoded = quote(pipeline_uuid, safe="")

        async with self.rate_limiter:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(
                    f"{self.base_url}/pipelines/{pipeline_uuid_encoded}/stopPipeline",
                    **self._auth_kwargs,
                )
                response.raise_for_status()
                if response.status_code == 204:
                    return {"status": "stopped", "pipeline_uuid": pipeline_uuid}
                return response.json()

    # ========================================================================
    # Branch Refs API (Sprint 7)
    # ========================================================================

    async def get_branches(
        self, query: Optional[str] = None, sort: str = "-target.date", pagelen: int = 25
    ) -> dict:
        """
        List branches in the repository

        Args:
            query: CQL filter (e.g., 'name ~ "feature"')
            sort: Sort order (default: most recently updated first)
            pagelen: Results per page (default: 25, max: 100)

        Returns:
            dict: Paginated list of branches with name, target commit, etc.
        """
        params = {"sort": sort, "pagelen": pagelen}
        if query:
            params["q"] = query

        async with self.rate_limiter:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.get(
                    f"{self.base_url}/refs/branches",
                    params=params,
                    **self._auth_kwargs,
                )
                response.raise_for_status()
                return response.json()

    async def get_branch(self, branch_name: str) -> dict:
        """
        Get details about a specific branch

        Args:
            branch_name: Branch name (slashes will be URL-encoded)

        Returns:
            dict: Branch object with name, target commit hash, merge strategies

        Raises:
            httpx.HTTPError: 404 if branch doesn't exist
        """
        branch_encoded = quote(branch_name, safe="")

        async with self.rate_limiter:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.get(
                    f"{self.base_url}/refs/branches/{branch_encoded}",
                    **self._auth_kwargs,
                )
                response.raise_for_status()
                return response.json()

    # ========================================================================
    # Branch Management API (Sprint 8 — VKS-1647)
    # ========================================================================

    async def create_branch(self, name: str, target_hash: str) -> dict:
        """
        Create a new branch from a commit hash.

        Args:
            name: Branch name (e.g., "main", "feature/my-feature").
            target_hash: Commit hash to branch from (full 40-char or short 7+ chars).

        Returns:
            dict: Created branch object with name, target commit, etc.

        Raises:
            ApiError: 400/409 if branch already exists, auth/network errors.
        """
        payload = {
            "name": name,
            "target": {"hash": target_hash},
        }
        return await request_json(
            method="POST",
            url=f"{self.base_url}/refs/branches",
            provider=self._provider_name,
            auth_hint=self._auth_hint,
            auth_kwargs=self._auth_kwargs,
            json=payload,
            timeout=30.0,
            limiter=self.rate_limiter,
            max_retries=0,  # non-idempotent: avoid duplicate branch creation
        )

    async def delete_branch(self, name: str) -> int:
        """
        Delete a branch from the repository.

        Args:
            name: Branch name (slashes will be URL-encoded).

        Returns:
            int: HTTP status code (204 on success).

        Raises:
            ApiError: 400 if default branch, 404 if not found, auth errors.
        """
        branch_encoded = quote(name, safe="")
        return await request_empty(
            method="DELETE",
            url=f"{self.base_url}/refs/branches/{branch_encoded}",
            provider=self._provider_name,
            auth_hint=self._auth_hint,
            auth_kwargs=self._auth_kwargs,
            timeout=30.0,
            limiter=self.rate_limiter,
            max_retries=0,  # destructive: never retry
        )

    async def set_default_branch(self, name: str) -> dict:
        """
        Change the default (main) branch of the repository.

        Uses PUT on the repository root endpoint, not /refs/.

        Args:
            name: Branch name to set as default (must already exist).

        Returns:
            dict: Updated repository object with mainbranch info.

        Raises:
            ApiError: 400 if branch doesn't exist, 403 if not admin.
        """
        payload = {
            "mainbranch": {"name": name},
        }
        return await request_json(
            method="PUT",
            url=self.base_url,
            provider=self._provider_name,
            auth_hint=self._auth_hint,
            auth_kwargs=self._auth_kwargs,
            json=payload,
            timeout=30.0,
            limiter=self.rate_limiter,
            max_retries=0,  # state-changing: no retry
        )

    async def get_branch_restrictions(self, pagelen: int = 100) -> dict:
        """
        List branch restrictions (protection rules) for the repository.

        Args:
            pagelen: Results per page (default: 100, max: 100).

        Returns:
            dict: Paginated list of branch restrictions with kind, pattern, users, groups.

        Raises:
            ApiError: Auth/network errors.
        """
        return await request_json(
            method="GET",
            url=f"{self.base_url}/branch-restrictions",
            provider=self._provider_name,
            auth_hint=self._auth_hint,
            auth_kwargs=self._auth_kwargs,
            params={"pagelen": pagelen},
            timeout=30.0,
            limiter=self.rate_limiter,
        )

    async def create_branch_restriction(
        self,
        kind: str,
        pattern: str,
        users: Optional[list] = None,
        groups: Optional[list] = None,
    ) -> dict:
        """
        Create a branch restriction (protection rule).

        Args:
            kind: Restriction type. Valid values:
                  push, force, delete, restrict_merges, deny_all_merges,
                  require_review_approvals, require_review_status_checks,
                  require_review_all_tasks_pending, require_default_merge_strategy,
                  allow_auto_merge_when_builds_pass, allow_auto_merge_when_builds_fail.
            pattern: Branch name pattern (glob-style: "main", "release/*").
            users: List of user UUIDs to exempt (omit = applies to all).
            groups: List of group slugs to exempt (omit = applies to all).

        Returns:
            dict: Created restriction object with id, kind, pattern.

        Raises:
            ApiError: 400 if invalid kind/pattern, 403 if not admin.
        """
        payload: dict = {
            "kind": kind,
            "pattern": pattern,
        }
        if users is not None:
            payload["users"] = [{"uuid": u} for u in users]
        if groups is not None:
            payload["groups"] = [{"slug": g} for g in groups]

        return await request_json(
            method="POST",
            url=f"{self.base_url}/branch-restrictions",
            provider=self._provider_name,
            auth_hint=self._auth_hint,
            auth_kwargs=self._auth_kwargs,
            json=payload,
            timeout=30.0,
            limiter=self.rate_limiter,
            max_retries=0,  # non-idempotent
        )

    async def delete_branch_restriction(self, restriction_id: int) -> int:
        """
        Delete a branch restriction by ID.

        Args:
            restriction_id: Restriction ID (obtained from get_branch_restrictions).

        Returns:
            int: HTTP status code (204 on success).

        Raises:
            ApiError: 404 if not found, 403 if not admin.
        """
        return await request_empty(
            method="DELETE",
            url=f"{self.base_url}/branch-restrictions/{restriction_id}",
            provider=self._provider_name,
            auth_hint=self._auth_hint,
            auth_kwargs=self._auth_kwargs,
            timeout=30.0,
            limiter=self.rate_limiter,
            max_retries=0,  # destructive: never retry
        )

    async def close(self):
        """
        Close any open connections (placeholder for cleanup if needed)
        """
        pass
