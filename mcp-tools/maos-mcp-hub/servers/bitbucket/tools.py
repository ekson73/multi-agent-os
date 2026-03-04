"""
Bitbucket Pipeline Monitor - Tool Implementations
"""

import sys
import asyncio
import hashlib
from datetime import datetime, timezone
from pathlib import Path
import httpx

# Add scripts directory to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from lib.bitbucket.client import BitbucketPipelineClient
from lib.bitbucket.analyzer import PipelineAnalyzer
from lib.bitbucket.health import HealthMonitor
from lib.bitbucket.validators import validate_build_number, validate_step_name, sanitize_error
from lib.common.errors import ApiError
from lib.common.http import sanitize_exception


# Global singleton instances
_client = None
_clients_by_repo: dict[str, BitbucketPipelineClient] = {}
_analyzer = None
_analyzers_by_repo: dict[str, PipelineAnalyzer] = {}
_health = None
_health_by_repo: dict[str, HealthMonitor] = {}


def get_client(repo_slug: str = "") -> BitbucketPipelineClient:
    """Get BitbucketPipelineClient with singleton cache (global + per-repo)."""
    global _client, _clients_by_repo
    if repo_slug:
        if repo_slug not in _clients_by_repo:
            _clients_by_repo[repo_slug] = BitbucketPipelineClient(repo_slug=repo_slug)
        return _clients_by_repo[repo_slug]
    if _client is None:
        _client = BitbucketPipelineClient()
    return _client


def get_analyzer(repo_slug: str = "") -> PipelineAnalyzer:
    """Get PipelineAnalyzer cache (global + per-repo)."""
    global _analyzer, _analyzers_by_repo
    if repo_slug:
        if repo_slug not in _analyzers_by_repo:
            _analyzers_by_repo[repo_slug] = PipelineAnalyzer(get_client(repo_slug))
        return _analyzers_by_repo[repo_slug]
    if _analyzer is None:
        _analyzer = PipelineAnalyzer(get_client())
    return _analyzer


def get_health(repo_slug: str = "") -> HealthMonitor:
    """Get HealthMonitor cache (global + per-repo)."""
    global _health, _health_by_repo
    if repo_slug:
        if repo_slug not in _health_by_repo:
            _health_by_repo[repo_slug] = HealthMonitor(get_client(repo_slug))
        return _health_by_repo[repo_slug]
    if _health is None:
        _health = HealthMonitor(get_client())
    return _health


# ============================================================================
# TOOL IMPLEMENTATIONS
# ============================================================================


async def get_recent_builds(count: int = 5, repo_slug: str = "") -> dict:
    """Get the most recent pipeline builds"""
    if count < 1 or count > 50:
        return {"error": "count must be between 1 and 50"}

    client = get_client(repo_slug)
    try:
        pipelines = await client.get_pipelines(pagelen=count)
    except ApiError as e:
        return {
            "error": "Failed to fetch recent builds",
            "details": sanitize_exception(e),
            "hint": e.hint,
        }
    except Exception as e:
        return {
            "error": "Failed to fetch recent builds",
            "details": sanitize_exception(e),
        }

    builds = []
    for p in pipelines.get("values", []):
        builds.append({
            "build_number": p["build_number"],
            "state": p.get("state", {}).get("name", "UNKNOWN"),
            "result": p.get("state", {}).get("result", {}).get("name", "IN_PROGRESS"),
            "commit": p.get("target", {}).get("commit", {}).get("hash", "")[:8],
            "branch": p.get("target", {}).get("ref_name", "unknown"),
            "created_on": p.get("created_on", ""),
        })

    return {"builds": builds, "count": len(builds)}


async def get_build_details(build_number: int, repo_slug: str = "") -> dict:
    """Get detailed information about a specific build"""
    validation_error = validate_build_number(build_number)
    if validation_error:
        return validation_error

    client = get_client(repo_slug)

    try:
        build = await client.get_pipeline(build_number)
    except ApiError as e:
        return {
            "error": f"Failed to fetch build {build_number}",
            "details": sanitize_exception(e),
            "hint": e.hint,
        }
    except Exception as e:
        return {
            "error": f"Failed to fetch build {build_number}",
            "details": sanitize_exception(e),
        }

    return {
        "build_number": build["build_number"],
        "state": build.get("state", {}).get("name", "UNKNOWN"),
        "result": build.get("state", {}).get("result", {}).get("name", "IN_PROGRESS"),
        "commit": {
            "hash": build.get("target", {}).get("commit", {}).get("hash", ""),
            "message": build.get("target", {}).get("commit", {}).get("message", ""),
        },
        "branch": build.get("target", {}).get("ref_name", "unknown"),
        "creator": build.get("creator", {}).get("display_name", "unknown"),
        "created_on": build.get("created_on", ""),
        "completed_on": build.get("completed_on"),
        "duration_seconds": build.get("duration_in_seconds"),
    }


async def get_build_steps(build_number: int, repo_slug: str = "") -> dict:
    """Get all steps for a specific build"""
    validation_error = validate_build_number(build_number)
    if validation_error:
        return validation_error

    client = get_client(repo_slug)

    try:
        steps_data = await client.get_pipeline_steps(build_number)
    except Exception as e:
        return {"error": f"Failed to fetch steps for build {build_number}", "details": str(e)}

    steps = []
    for s in steps_data.get("values", []):
        steps.append({
            "name": s.get("name", "unknown"),
            "uuid": s.get("uuid", ""),
            "state": s.get("state", {}).get("name", "UNKNOWN"),
            "result": s.get("state", {}).get("result", {}).get("name", "N/A"),
            "duration_seconds": s.get("duration_in_seconds"),
            "created_on": s.get("started_on"),
            "completed_on": s.get("completed_on"),
        })

    return {"build_number": build_number, "steps": steps, "count": len(steps)}


async def get_step_logs(build_number: int, step_name: str, repo_slug: str = "") -> dict:
    """Get logs for a specific build step"""
    validation_error = validate_build_number(build_number)
    if validation_error:
        return validation_error

    validation_error = validate_step_name(step_name)
    if validation_error:
        return validation_error

    client = get_client(repo_slug)

    try:
        steps_data = await client.get_pipeline_steps(build_number)
    except ApiError as e:
        return {
            "error": f"Failed to fetch steps for build {build_number}",
            "details": sanitize_exception(e),
            "hint": e.hint,
        }
    except Exception as e:
        return {
            "error": f"Failed to fetch steps for build {build_number}",
            "details": sanitize_exception(e),
        }

    # Find step by name
    step = next((s for s in steps_data.get("values", []) if s.get("name") == step_name), None)

    if not step:
        available_steps = [s.get("name", "unknown") for s in steps_data.get("values", [])]
        return {
            "error": "Step not found",
            "step_name": step_name,
            "available_steps": available_steps,
        }

    step_uuid = step.get("uuid", "").strip("{}")

    try:
        logs = await client.get_step_log(build_number, step_uuid)
        return {
            "step_name": step_name,
            "step_uuid": step_uuid,
            "state": step.get("state", {}).get("name", "UNKNOWN"),
            "result": step.get("state", {}).get("result", {}).get("name", "N/A"),
            "logs": logs,
        }
    except ApiError as e:
        return {
            "error": "Logs not available",
            "details": sanitize_exception(e),
            "hint": e.hint,
            "step_name": step_name,
            "step_uuid": step_uuid,
            "state": step.get("state", {}).get("name", "UNKNOWN"),
            "result": step.get("state", {}).get("result", {}).get("name", "N/A"),
        }
    except Exception as e:
        return {
            "error": "Logs not available",
            "details": sanitize_exception(e),
            "step_name": step_name,
            "step_uuid": step_uuid,
            "state": step.get("state", {}).get("name", "UNKNOWN"),
            "result": step.get("state", {}).get("result", {}).get("name", "N/A"),
        }


async def analyze_failures(count: int = 10, repo_slug: str = "") -> dict:
    """Analyze patterns in recent failed builds"""
    if count < 1 or count > 50:
        return {"error": "count must be between 1 and 50"}

    analyzer = get_analyzer(repo_slug)
    return await analyzer.analyze_failure_patterns(count)


async def auto_diagnose(build_number: int, repo_slug: str = "") -> dict:
    """Automatically diagnose a failed build with actionable suggestions"""
    validation_error = validate_build_number(build_number)
    if validation_error:
        return validation_error

    analyzer = get_analyzer(repo_slug)
    return await analyzer.diagnose_build(build_number)


async def compare_builds(build1: int, build2: int, repo_slug: str = "") -> dict:
    """Compare two builds step-by-step"""
    validation_error = validate_build_number(build1)
    if validation_error:
        validation_error["parameter"] = "build1"
        return validation_error

    validation_error = validate_build_number(build2)
    if validation_error:
        validation_error["parameter"] = "build2"
        return validation_error

    analyzer = get_analyzer(repo_slug)
    return await analyzer.compare_builds(build1, build2)


async def check_pipeline_health(repo_slug: str = "") -> dict:
    """Check overall pipeline health and metrics"""
    health = get_health(repo_slug)
    health_data = await health.check_health()
    return health_data.model_dump()


async def check_alerts(repo_slug: str = "") -> dict:
    """Check for pipeline alerts and issues"""
    health = get_health(repo_slug)
    return await health.check_alerts()


async def get_executive_summary(repo_slug: str = "") -> dict:
    """Generate comprehensive executive summary report"""
    health = get_health(repo_slug)
    analyzer = get_analyzer(repo_slug)

    # Gather all data in parallel
    health_data, alerts_data, failure_patterns = await asyncio.gather(
        health.check_health(sample_size=30),
        health.check_alerts(),
        analyzer.analyze_failure_patterns(count=20),
    )

    return {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "health": health_data.model_dump(),
        "alerts": alerts_data,
        "failure_trends": {
            "total_failed_builds": len(failure_patterns.get("failed_builds", [])),
            "most_common_failures": failure_patterns.get("most_common_failures", []),
        },
        "recommendations": alerts_data.get("recommendations", []),
    }


# ============================================================================
# TEST REPORTS TOOLS (Sprint 1 - 2025-10-31)
# ============================================================================


async def get_test_reports(build_number: int, step_name: str, repo_slug: str = "") -> dict:
    """
    Get test report summary for a pipeline step

    Args:
        build_number: Build number to query (e.g., 640)
        step_name: Name of the step (e.g., "Unit Tests")

    Returns:
        dict: Test report summary with counts and duration
    """
    client = get_client(repo_slug)

    try:
        # Get steps to resolve step_name → step_uuid
        steps_response = await client.get_pipeline_steps(build_number)
        steps = steps_response.get("values", [])

        # Find step by name
        target_step = None
        for step in steps:
            if step.get("name") == step_name:
                target_step = step
                break

        if not target_step:
            return {
                "error": f"Step '{step_name}' not found in build #{build_number}",
                "build_number": build_number,
                "available_steps": [s.get("name") for s in steps],
            }

        step_uuid = target_step.get("uuid")

        # Get test reports
        test_reports_response = await client.get_test_reports(build_number, step_uuid)

        # Extract first report (usually only one)
        values = test_reports_response.get("values", [])
        if not values:
            return {
                "build_number": build_number,
                "step_name": step_name,
                "step_uuid": step_uuid,
                "test_report_summary": None,
                "message": "No test reports found for this step (step may not have run tests)",
            }

        report = values[0]

        # Format response
        return {
            "build_number": build_number,
            "step_name": step_name,
            "step_uuid": step_uuid,
            "test_report_summary": {
                "total_tests": report.get("test_count", 0),
                "passed": report.get("successful_test_count", 0),
                "failed": report.get("failed_test_count", 0),
                "skipped": report.get("skipped_test_count", 0),
                "duration_seconds": report.get("duration", 0.0),
            },
            "has_failures": report.get("failed_test_count", 0) > 0,
        }

    except ApiError as e:
        return {
            "error": "Failed to get test reports",
            "details": sanitize_exception(e),
            "hint": e.hint,
            "build_number": build_number,
            "step_name": step_name,
        }
    except httpx.HTTPStatusError as e:
        return {
            "error": f"Failed to get test reports: {sanitize_error(e)}",
            "build_number": build_number,
            "step_name": step_name,
        }


async def get_test_cases(build_number: int, step_name: str, status: str = "all", repo_slug: str = "") -> dict:
    """
    Get test cases for a pipeline step with optional status filter

    Args:
        build_number: Build number to query (e.g., 640)
        step_name: Name of the step (e.g., "Unit Tests")
        status: Filter by status: "all", "passed", "failed", "skipped" (default: "all")

    Returns:
        dict: List of test cases matching the filter
    """
    client = get_client(repo_slug)

    try:
        # Get steps to resolve step_name → step_uuid
        steps_response = await client.get_pipeline_steps(build_number)
        steps = steps_response.get("values", [])

        # Find step by name
        target_step = None
        for step in steps:
            if step.get("name") == step_name:
                target_step = step
                break

        if not target_step:
            return {
                "error": f"Step '{step_name}' not found in build #{build_number}",
                "build_number": build_number,
                "available_steps": [s.get("name") for s in steps],
            }

        step_uuid = target_step.get("uuid")

        # Get test cases
        test_cases_response = await client.get_test_cases(build_number, step_uuid)

        # Extract test cases
        all_test_cases = test_cases_response.get("values", [])

        # Filter by status if requested
        if status != "all":
            status_upper = status.upper()
            filtered_cases = [
                tc for tc in all_test_cases
                if tc.get("status", "").upper() == status_upper
            ]
        else:
            filtered_cases = all_test_cases

        # Format response
        formatted_cases = []
        for tc in filtered_cases:
            formatted_cases.append({
                "uuid": tc.get("uuid"),
                "name": tc.get("name"),
                "class_name": tc.get("class_name"),
                "status": tc.get("status"),
                "duration_seconds": tc.get("duration", 0.0),
            })

        return {
            "build_number": build_number,
            "step_name": step_name,
            "filter_status": status,
            "test_cases": formatted_cases,
            "count": len(formatted_cases),
        }

    except ApiError as e:
        return {
            "error": "Failed to get test cases",
            "details": sanitize_exception(e),
            "hint": e.hint,
            "build_number": build_number,
            "step_name": step_name,
        }
    except httpx.HTTPStatusError as e:
        return {
            "error": f"Failed to get test cases: {sanitize_error(e)}",
            "build_number": build_number,
            "step_name": step_name,
        }


async def get_test_case_reasons(build_number: int, step_name: str, test_case_name: str, repo_slug: str = "") -> dict:
    """
    Get failure reasons (stack trace) for a specific test case

    Args:
        build_number: Build number to query (e.g., 640)
        step_name: Name of the step (e.g., "Unit Tests")
        test_case_name: Name of the test case (e.g., "test_user_authentication")

    Returns:
        dict: Failure reasons with message and stack trace
    """
    client = get_client(repo_slug)

    try:
        # Get steps to resolve step_name → step_uuid
        steps_response = await client.get_pipeline_steps(build_number)
        steps = steps_response.get("values", [])

        # Find step by name
        target_step = None
        for step in steps:
            if step.get("name") == step_name:
                target_step = step
                break

        if not target_step:
            return {
                "error": f"Step '{step_name}' not found in build #{build_number}",
                "build_number": build_number,
                "available_steps": [s.get("name") for s in steps],
            }

        step_uuid = target_step.get("uuid")

        # Get all test cases to find the one by name
        test_cases_response = await client.get_test_cases(build_number, step_uuid)
        all_test_cases = test_cases_response.get("values", [])

        # Find test case by name
        target_test_case = None
        for tc in all_test_cases:
            if tc.get("name") == test_case_name:
                target_test_case = tc
                break

        if not target_test_case:
            return {
                "error": f"Test case '{test_case_name}' not found",
                "build_number": build_number,
                "step_name": step_name,
                "available_test_cases": [tc.get("name") for tc in all_test_cases][:20],  # Limit to 20
            }

        test_case_uuid = target_test_case.get("uuid")

        # Get failure reasons
        reasons_response = await client.get_test_case_reasons(
            build_number, step_uuid, test_case_uuid
        )

        # Extract reasons
        reasons = reasons_response.get("values", [])

        # Format response
        formatted_reasons = []
        for reason in reasons:
            formatted_reasons.append({
                "type": reason.get("type"),
                "message": reason.get("message"),
                "stack_trace": reason.get("stack_trace"),
            })

        return {
            "build_number": build_number,
            "step_name": step_name,
            "test_case_name": test_case_name,
            "test_case_uuid": test_case_uuid,
            "test_case_status": target_test_case.get("status"),
            "failure_reasons": formatted_reasons,
        }

    except ApiError as e:
        return {
            "error": "Failed to get test case reasons",
            "details": sanitize_exception(e),
            "hint": e.hint,
            "build_number": build_number,
            "step_name": step_name,
            "test_case_name": test_case_name,
        }
    except httpx.HTTPStatusError as e:
        return {
            "error": f"Failed to get test case reasons: {sanitize_error(e)}",
            "build_number": build_number,
            "step_name": step_name,
            "test_case_name": test_case_name,
        }


# ============================================================================
# DEPLOYMENTS & VARIABLES TOOLS (Sprint 2 - 2025-10-31)
# ============================================================================


async def get_recent_deployments(environment: str | None = None, count: int = 5, repo_slug: str = "") -> dict:
    """
    Get recent deployments for the repository

    Args:
        environment: Filter by environment name (e.g., "Production", "Staging", "Test")
        count: Number of deployments to return (default: 5)

    Returns:
        dict: Recent deployments with status and timestamps
    """
    try:
        client = get_client(repo_slug)
        data = await client.get_deployments(environment=environment, pagelen=count)

        deployments = []
        for d in data.get("values", []):
            state_info = d.get("state", {})
            env_info = d.get("environment", {})

            deployments.append({
                "uuid": d.get("uuid"),
                "environment": env_info.get("name"),
                "state": state_info.get("name"),
                "status": state_info.get("status", {}).get("name"),
                "release": d.get("release", {}).get("name"),
                "created_on": d.get("created_on"),
                "completed_on": d.get("completed_on"),
            })

        return {
            "environment_filter": environment or "all",
            "count": len(deployments),
            "deployments": deployments,
        }

    except httpx.HTTPStatusError as e:
        return {
            "error": f"Failed to get deployments: {sanitize_error(e)}",
            "environment": environment,
        }


async def get_deployment_details(deployment_uuid: str, repo_slug: str = "") -> dict:
    """
    Get detailed information about a specific deployment

    Args:
        deployment_uuid: Deployment UUID (with or without curly braces)

    Returns:
        dict: Deployment details including environment, state, and timeline
    """
    try:
        client = get_client(repo_slug)
        data = await client.get_deployment(deployment_uuid)

        state_info = data.get("state", {})
        env_info = data.get("environment", {})
        deployable_info = data.get("deployable", {})

        return {
            "uuid": data.get("uuid"),
            "environment": {
                "name": env_info.get("name"),
                "uuid": env_info.get("uuid"),
                "type": env_info.get("environment_type", {}).get("name"),
            },
            "state": state_info.get("name"),
            "status": state_info.get("status", {}).get("name"),
            "deployable": {
                "type": deployable_info.get("type"),
                "uuid": deployable_info.get("uuid"),
            },
            "release": data.get("release", {}).get("name"),
            "created_on": data.get("created_on"),
            "completed_on": data.get("completed_on"),
            "deployment_variables": data.get("deployment_variables", []),
        }

    except httpx.HTTPStatusError as e:
        return {
            "error": f"Failed to get deployment details: {sanitize_error(e)}",
            "deployment_uuid": deployment_uuid,
        }


async def get_environments(repo_slug: str = "") -> dict:
    """
    Get all deployment environments configured for the repository

    Returns:
        dict: List of environments with names, slugs, and types
    """
    try:
        client = get_client(repo_slug)
        data = await client.get_environments()

        environments = []
        for env in data.get("values", []):
            env_type = env.get("environment_type", {})
            environments.append({
                "uuid": env.get("uuid"),
                "name": env.get("name"),
                "slug": env.get("slug"),
                "type": env_type.get("name"),
                "rank": env_type.get("rank"),
            })

        # Sort by rank (Production=1, Staging=2, Test=3)
        environments.sort(key=lambda e: e.get("rank", 999))

        return {
            "count": len(environments),
            "environments": environments,
        }

    except httpx.HTTPStatusError as e:
        return {"error": f"Failed to get environments: {sanitize_error(e)}"}


async def get_environment_variables(environment_name: str, repo_slug: str = "") -> dict:
    """
    Get all variables configured for a specific environment

    Args:
        environment_name: Environment name (e.g., "Production", "Staging")

    Returns:
        dict: List of environment variables (secured values are masked)

    Note:
        Secured variables will not show the "value" field (Bitbucket security policy)
    """
    try:
        client = get_client(repo_slug)

        # First, get environment UUID by name
        envs_data = await client.get_environments()
        target_env = None
        for env in envs_data.get("values", []):
            if env.get("name") == environment_name:
                target_env = env
                break

        if not target_env:
            return {
                "error": f"Environment '{environment_name}' not found",
                "available_environments": [
                    e.get("name") for e in envs_data.get("values", [])
                ],
            }

        # Get variables for this environment
        env_uuid = target_env.get("uuid")
        data = await client.get_environment_variables(env_uuid)

        variables = []
        for var in data.get("values", []):
            var_info = {
                "key": var.get("key"),
                "secured": var.get("secured", False),
                "type": var.get("type"),
            }

            # Only include value if not secured
            if not var.get("secured"):
                var_info["value"] = var.get("value")
            else:
                var_info["value"] = "***SECURED***"

            variables.append(var_info)

        return {
            "environment": environment_name,
            "environment_uuid": env_uuid,
            "count": len(variables),
            "variables": variables,
        }

    except httpx.HTTPStatusError as e:
        return {
            "error": f"Failed to get environment variables: {sanitize_error(e)}",
            "environment": environment_name,
        }


async def get_repository_variables(repo_slug: str = "") -> dict:
    """
    Get all pipeline variables configured at repository level

    Returns:
        dict: List of repository variables (secured values are masked)

    Note:
        Secured variables will not show the "value" field (Bitbucket security policy)
    """
    try:
        client = get_client(repo_slug)
        data = await client.get_repository_variables()

        variables = []
        for var in data.get("values", []):
            var_info = {
                "key": var.get("key"),
                "secured": var.get("secured", False),
                "type": var.get("type"),
            }

            # Only include value if not secured
            if not var.get("secured"):
                var_info["value"] = var.get("value")
            else:
                var_info["value"] = "***SECURED***"

            variables.append(var_info)

        return {
            "scope": "repository",
            "count": len(variables),
            "variables": variables,
        }

    except httpx.HTTPStatusError as e:
        return {"error": f"Failed to get repository variables: {sanitize_error(e)}"}


async def get_workspace_variables(repo_slug: str = "") -> dict:
    """
    Get all pipeline variables configured at workspace level

    Returns:
        dict: List of workspace variables (secured values are masked)

    Note:
        Secured variables will not show the "value" field (Bitbucket security policy)
    """
    try:
        client = get_client(repo_slug)
        data = await client.get_workspace_variables()

        variables = []
        for var in data.get("values", []):
            var_info = {
                "key": var.get("key"),
                "secured": var.get("secured", False),
                "type": var.get("type"),
            }

            # Only include value if not secured
            if not var.get("secured"):
                var_info["value"] = var.get("value")
            else:
                var_info["value"] = "***SECURED***"

            variables.append(var_info)

        return {
            "scope": "workspace",
            "workspace": client.repo_slug.split("/")[0],
            "count": len(variables),
            "variables": variables,
        }

    except httpx.HTTPStatusError as e:
        return {"error": f"Failed to get workspace variables: {sanitize_error(e)}"}


# ============================================================================
# CACHE MANAGEMENT TOOLS (Sprint 3 - 2025-10-31)
# ============================================================================


async def list_caches(repo_slug: str = "") -> dict:
    """
    List all configured pipeline caches for the repository

    Returns:
        dict: List of caches with names, paths, and enabled status
    """
    try:
        client = get_client(repo_slug)
        data = await client.get_caches()

        caches = []
        for cache in data.get("values", []):
            caches.append({
                "name": cache.get("name"),
                "path": cache.get("path"),
                "enabled": cache.get("enabled", True),
            })

        return {
            "count": len(caches),
            "caches": caches,
        }

    except httpx.HTTPStatusError as e:
        return {"error": f"Failed to list caches: {sanitize_error(e)}"}


async def get_cache_details(cache_name: str, repo_slug: str = "") -> dict:
    """
    Get details about a specific cache including size and content URI

    Args:
        cache_name: Name of the cache (e.g., "maven", "gradle", "node")

    Returns:
        dict: Cache details including size, content URI, and last usage

    Note:
        Returns 404 if cache has never been used (no content yet)
    """
    try:
        client = get_client(repo_slug)

        # Get cache configuration first
        caches_data = await client.get_caches()
        cache_config = None
        for cache in caches_data.get("values", []):
            if cache.get("name") == cache_name:
                cache_config = cache
                break

        if not cache_config:
            return {
                "error": f"Cache '{cache_name}' not found in configuration",
                "available_caches": [c.get("name") for c in caches_data.get("values", [])],
            }

        # Try to get cache content URI (may 404 if never used)
        try:
            content_data = await client.get_cache_content_uri(cache_name)

            # Calculate size in MB
            size_bytes = content_data.get("size", 0)
            size_mb = round(size_bytes / (1024 * 1024), 2) if size_bytes else 0

            return {
                "name": cache_name,
                "path": cache_config.get("path"),
                "enabled": cache_config.get("enabled", True),
                "size_bytes": size_bytes,
                "size_mb": size_mb,
                "content_uri": content_data.get("content_uri"),
                "created_on": content_data.get("created_on"),
                "has_content": True,
            }

        except httpx.HTTPStatusError as content_error:
            if content_error.response.status_code == 404:
                # Cache exists but has no content yet (never used)
                return {
                    "name": cache_name,
                    "path": cache_config.get("path"),
                    "enabled": cache_config.get("enabled", True),
                    "has_content": False,
                    "message": "Cache configured but never used (no content yet)",
                }
            raise  # Re-raise for other errors

    except httpx.HTTPStatusError as e:
        return {
            "error": f"Failed to get cache details: {sanitize_error(e)}",
            "cache_name": cache_name,
        }


async def clear_cache(cache_name: str, repo_slug: str = "") -> dict:
    """
    Clear (delete) a specific pipeline cache

    Args:
        cache_name: Name of the cache to clear (e.g., "maven", "gradle")

    Returns:
        dict: Confirmation of cache deletion

    Note:
        - Requires write permissions on repository
        - Only clears cached content, not configuration
        - Next build will recreate cache from scratch
    """
    try:
        client = get_client(repo_slug)

        # Verify cache exists first
        caches_data = await client.get_caches()
        cache_exists = any(c.get("name") == cache_name for c in caches_data.get("values", []))

        if not cache_exists:
            return {
                "error": f"Cache '{cache_name}' not found",
                "available_caches": [c.get("name") for c in caches_data.get("values", [])],
            }

        # Delete the cache
        result = await client.delete_cache(cache_name)

        return {
            "status": result.get("status", "deleted"),
            "cache_name": cache_name,
            "message": f"Cache '{cache_name}' cleared successfully",
            "note": "Next build will recreate cache from scratch",
        }

    except httpx.HTTPStatusError as e:
        error_msg = sanitize_error(e)

        # Check for permission error
        if e.response.status_code == 403:
            return {
                "error": f"Permission denied: {error_msg}",
                "cache_name": cache_name,
                "note": "Requires write permissions on repository",
            }

        return {
            "error": f"Failed to clear cache: {error_msg}",
            "cache_name": cache_name,
        }


async def analyze_cache_efficiency(repo_slug: str = "") -> dict:
    """
    Analyze cache efficiency across all configured caches

    Returns:
        dict: Efficiency metrics and recommendations
    """
    try:
        client = get_client(repo_slug)

        # Get all caches
        caches_data = await client.get_caches()
        caches = caches_data.get("values", [])

        if not caches:
            return {
                "total_caches": 0,
                "message": "No caches configured",
                "recommendation": "Consider adding caches to speed up builds",
            }

        # Analyze each cache
        cache_stats = []
        total_size_bytes = 0
        caches_with_content = 0

        for cache in caches:
            cache_name = cache.get("name")

            try:
                content_data = await client.get_cache_content_uri(cache_name)
                size_bytes = content_data.get("size", 0)
                size_mb = round(size_bytes / (1024 * 1024), 2) if size_bytes else 0

                total_size_bytes += size_bytes
                caches_with_content += 1

                cache_stats.append({
                    "name": cache_name,
                    "size_mb": size_mb,
                    "size_bytes": size_bytes,
                    "path": cache.get("path"),
                    "status": "active",
                    "created_on": content_data.get("created_on"),
                })

            except httpx.HTTPStatusError as e:
                if e.response.status_code == 404:
                    # Cache never used
                    cache_stats.append({
                        "name": cache_name,
                        "size_mb": 0,
                        "size_bytes": 0,
                        "path": cache.get("path"),
                        "status": "unused",
                    })

        # Calculate metrics
        total_size_mb = round(total_size_bytes / (1024 * 1024), 2)
        usage_rate = round((caches_with_content / len(caches)) * 100, 1) if caches else 0

        # Sort by size (largest first)
        cache_stats.sort(key=lambda x: x.get("size_bytes", 0), reverse=True)

        # Generate recommendations
        recommendations = []

        if caches_with_content == 0:
            recommendations.append("No caches are being used. Check if caches are properly configured in bitbucket-pipelines.yml")
        elif usage_rate < 50:
            recommendations.append(f"Only {usage_rate}% of configured caches are being used. Consider removing unused cache definitions")

        largest_cache = cache_stats[0] if cache_stats else None
        if largest_cache and largest_cache.get("size_mb", 0) > 500:
            recommendations.append(f"Cache '{largest_cache['name']}' is {largest_cache['size_mb']}MB. Consider optimizing or clearing if builds are slow")

        unused_caches = [c["name"] for c in cache_stats if c.get("status") == "unused"]
        if unused_caches:
            recommendations.append(f"Unused caches: {', '.join(unused_caches)}. Consider removing from bitbucket-pipelines.yml")

        return {
            "total_caches": len(caches),
            "active_caches": caches_with_content,
            "unused_caches": len(caches) - caches_with_content,
            "usage_rate_percent": usage_rate,
            "total_size_mb": total_size_mb,
            "total_size_bytes": total_size_bytes,
            "cache_stats": cache_stats,
            "recommendations": recommendations if recommendations else ["All caches are healthy"],
        }

    except httpx.HTTPStatusError as e:
        return {"error": f"Failed to analyze caches: {sanitize_error(e)}"}


# ============================================================================
# COMMITS & BUILD STATUS TOOLS (Sprint 4)
# ============================================================================

async def get_commit_details(commit_hash: str, repo_slug: str = "") -> dict:
    """
    Get detailed information about a specific commit

    Args:
        commit_hash: Commit hash (full or short SHA)

    Returns:
        dict: Commit details with author, date, message, parents
    """
    client = get_client(repo_slug)

    try:
        commit = await client.get_commit(commit_hash)

        # Format response
        return {
            "hash": commit.get("hash", ""),
            "author": {
                "name": commit.get("author", {}).get("raw", "Unknown"),
                "user": commit.get("author", {}).get("user", {}).get("display_name", "N/A")
            },
            "date": commit.get("date", ""),
            "message": commit.get("message", "").strip(),
            "summary": commit.get("summary", {}).get("raw", ""),
            "parents": [p.get("hash", "")[:8] for p in commit.get("parents", [])],
            "links": {
                "self": commit.get("links", {}).get("self", {}).get("href", ""),
                "html": commit.get("links", {}).get("html", {}).get("href", "")
            }
        }

    except httpx.HTTPStatusError as e:
        if e.response.status_code == 404:
            return {"error": f"Commit '{commit_hash}' not found"}
        return {"error": f"Failed to get commit details: {sanitize_error(e)}"}


async def get_commit_build_statuses(commit_hash: str, repo_slug: str = "") -> dict:
    """
    Get all build statuses for a specific commit

    This includes Bitbucket Pipelines and external CI systems (Jenkins, etc.)

    Args:
        commit_hash: Commit hash (full or short SHA)

    Returns:
        dict: Build statuses with state, name, URL, timestamps
    """
    client = get_client(repo_slug)

    try:
        statuses_response = await client.get_commit_statuses(commit_hash)
        statuses = statuses_response.get("values", [])

        # Count statuses by state
        state_counts = {
            "SUCCESSFUL": 0,
            "FAILED": 0,
            "INPROGRESS": 0,
            "STOPPED": 0
        }

        formatted_statuses = []
        for status in statuses:
            state = status.get("state", "UNKNOWN")
            if state in state_counts:
                state_counts[state] += 1

            formatted_statuses.append({
                "key": status.get("key", ""),
                "name": status.get("name", ""),
                "state": state,
                "url": status.get("url", ""),
                "description": status.get("description", ""),
                "created_on": status.get("created_on", ""),
                "updated_on": status.get("updated_on", "")
            })

        # Calculate overall state
        if state_counts["FAILED"] > 0:
            overall_state = "FAILED"
        elif state_counts["INPROGRESS"] > 0:
            overall_state = "INPROGRESS"
        elif state_counts["STOPPED"] > 0:
            overall_state = "STOPPED"
        elif state_counts["SUCCESSFUL"] > 0:
            overall_state = "SUCCESSFUL"
        else:
            overall_state = "UNKNOWN"

        return {
            "commit_hash": commit_hash,
            "total_statuses": len(statuses),
            "overall_state": overall_state,
            "state_counts": state_counts,
            "statuses": formatted_statuses
        }

    except httpx.HTTPStatusError as e:
        if e.response.status_code == 404:
            return {"error": f"Commit '{commit_hash}' not found"}
        return {"error": f"Failed to get commit statuses: {sanitize_error(e)}"}


async def get_builds_for_commit(commit_hash: str, repo_slug: str = "") -> dict:
    """
    Get all Bitbucket Pipeline builds for a specific commit (aggregation)

    Combines commit statuses with build details for complete view

    Args:
        commit_hash: Commit hash (full or short SHA)

    Returns:
        dict: Complete build information for the commit
    """
    client = get_client(repo_slug)

    try:
        # Get commit details
        commit = await client.get_commit(commit_hash)

        # Get build statuses
        statuses_response = await client.get_commit_statuses(commit_hash)
        statuses = statuses_response.get("values", [])

        # Filter Bitbucket Pipeline builds (key starts with "PIPELINE")
        pipeline_builds = []
        external_builds = []

        for status in statuses:
            key = status.get("key", "")
            build_info = {
                "name": status.get("name", ""),
                "state": status.get("state", ""),
                "url": status.get("url", ""),
                "created_on": status.get("created_on", ""),
                "updated_on": status.get("updated_on", "")
            }

            if key.startswith("PIPELINE"):
                pipeline_builds.append(build_info)
            else:
                external_builds.append(build_info)

        return {
            "commit": {
                "hash": commit.get("hash", "")[:8],
                "message": commit.get("message", "").strip()[:100],
                "author": commit.get("author", {}).get("raw", "Unknown"),
                "date": commit.get("date", "")
            },
            "pipeline_builds": pipeline_builds,
            "pipeline_build_count": len(pipeline_builds),
            "external_builds": external_builds,
            "external_build_count": len(external_builds),
            "total_builds": len(statuses)
        }

    except httpx.HTTPStatusError as e:
        if e.response.status_code == 404:
            return {"error": f"Commit '{commit_hash}' not found"}
        return {"error": f"Failed to get builds for commit: {sanitize_error(e)}"}


async def compare_commit_builds(commit_hash1: str, commit_hash2: str, repo_slug: str = "") -> dict:
    """
    Compare build statuses between two commits (aggregation + analysis)

    Useful for identifying regressions or improvements between commits

    Args:
        commit_hash1: First commit hash
        commit_hash2: Second commit hash

    Returns:
        dict: Comparative analysis of builds between commits
    """
    client = get_client(repo_slug)

    try:
        # Get builds for both commits
        builds1_response = await client.get_commit_statuses(commit_hash1)
        builds2_response = await client.get_commit_statuses(commit_hash2)

        statuses1 = builds1_response.get("values", [])
        statuses2 = builds2_response.get("values", [])

        # Count states for each commit
        def count_states(statuses):
            counts = {"SUCCESSFUL": 0, "FAILED": 0, "INPROGRESS": 0, "STOPPED": 0}
            for s in statuses:
                state = s.get("state", "")
                if state in counts:
                    counts[state] += 1
            return counts

        counts1 = count_states(statuses1)
        counts2 = count_states(statuses2)

        # Calculate differences
        differences = {
            "successful_delta": counts2["SUCCESSFUL"] - counts1["SUCCESSFUL"],
            "failed_delta": counts2["FAILED"] - counts1["FAILED"],
            "total_delta": len(statuses2) - len(statuses1)
        }

        # Determine regression/improvement
        if counts2["FAILED"] > counts1["FAILED"]:
            analysis = "REGRESSION: More failures in second commit"
        elif counts2["FAILED"] < counts1["FAILED"]:
            analysis = "IMPROVEMENT: Fewer failures in second commit"
        elif counts2["SUCCESSFUL"] > counts1["SUCCESSFUL"]:
            analysis = "IMPROVEMENT: More successful builds in second commit"
        else:
            analysis = "NEUTRAL: Similar build outcomes"

        return {
            "commit1": {
                "hash": commit_hash1,
                "total_builds": len(statuses1),
                "state_counts": counts1
            },
            "commit2": {
                "hash": commit_hash2,
                "total_builds": len(statuses2),
                "state_counts": counts2
            },
            "differences": differences,
            "analysis": analysis
        }

    except httpx.HTTPStatusError as e:
        if e.response.status_code == 404:
            return {"error": "One or both commits not found"}
        return {"error": f"Failed to compare commits: {sanitize_error(e)}"}


# ============================================================================
# PULL REQUESTS & CONFIGURATION TOOLS (Sprint 5)
# ============================================================================

async def get_pull_requests(state: str = "OPEN", count: int = 10, repo_slug: str = "") -> dict:
    """
    Get pull requests for the repository

    Args:
        state: PR state (OPEN, MERGED, DECLINED, SUPERSEDED)
        count: Number of PRs to return (default 10, max 100)

    Returns:
        dict: List of pull requests with title, author, branches, dates
    """
    client = get_client(repo_slug)

    try:
        prs_response = await client.get_pull_requests(state=state, pagelen=count)
        prs = prs_response.get("values", [])

        formatted_prs = []
        for pr in prs:
            formatted_prs.append({
                "id": pr.get("id"),
                "title": pr.get("title", ""),
                "state": pr.get("state", ""),
                "author": pr.get("author", {}).get("display_name", "Unknown"),
                "source_branch": pr.get("source", {}).get("branch", {}).get("name", ""),
                "destination_branch": pr.get("destination", {}).get("branch", {}).get("name", ""),
                "created_on": pr.get("created_on", ""),
                "updated_on": pr.get("updated_on", ""),
                "links": pr.get("links", {}).get("html", {}).get("href", "")
            })

        return {
            "state_filter": state,
            "total_prs": len(formatted_prs),
            "pull_requests": formatted_prs
        }

    except httpx.HTTPStatusError as e:
        return {"error": f"Failed to get pull requests: {sanitize_error(e)}"}


async def get_pr_details(pr_id: int, repo_slug: str = "") -> dict:
    """
    Get detailed information about a specific pull request

    Args:
        pr_id: Pull request ID

    Returns:
        dict: PR details with reviewers, description, merge info
    """
    client = get_client(repo_slug)

    try:
        pr = await client.get_pull_request(pr_id)

        # Format reviewers
        reviewers = []
        for reviewer in pr.get("reviewers", []):
            reviewers.append({
                "display_name": reviewer.get("display_name", ""),
                "approved": reviewer.get("approved", False)
            })

        return {
            "id": pr.get("id"),
            "title": pr.get("title", ""),
            "description": pr.get("description", "")[:500],  # Truncate long descriptions
            "state": pr.get("state", ""),
            "author": pr.get("author", {}).get("display_name", "Unknown"),
            "reviewers": reviewers,
            "source": {
                "branch": pr.get("source", {}).get("branch", {}).get("name", ""),
                "commit": pr.get("source", {}).get("commit", {}).get("hash", "")[:8]
            },
            "destination": {
                "branch": pr.get("destination", {}).get("branch", {}).get("name", ""),
                "commit": pr.get("destination", {}).get("commit", {}).get("hash", "")[:8]
            },
            "merge_commit": pr.get("merge_commit", {}).get("hash", "")[:8] if pr.get("merge_commit") else None,
            "created_on": pr.get("created_on", ""),
            "updated_on": pr.get("updated_on", ""),
            "links": {
                "html": pr.get("links", {}).get("html", {}).get("href", ""),
                "diff": pr.get("links", {}).get("diff", {}).get("href", "")
            }
        }

    except httpx.HTTPStatusError as e:
        if e.response.status_code == 404:
            return {"error": f"Pull request #{pr_id} not found"}
        return {"error": f"Failed to get PR details: {sanitize_error(e)}"}


async def get_pr_build_statuses(pr_id: int, repo_slug: str = "") -> dict:
    """
    Get all build statuses for a specific pull request

    Args:
        pr_id: Pull request ID

    Returns:
        dict: Build statuses with overall state
    """
    client = get_client(repo_slug)

    try:
        statuses_response = await client.get_pr_statuses(pr_id)
        statuses = statuses_response.get("values", [])

        # Count by state
        state_counts = {
            "SUCCESSFUL": 0,
            "FAILED": 0,
            "INPROGRESS": 0,
            "STOPPED": 0
        }

        formatted_statuses = []
        for status in statuses:
            state = status.get("state", "UNKNOWN")
            if state in state_counts:
                state_counts[state] += 1

            formatted_statuses.append({
                "name": status.get("name", ""),
                "state": state,
                "url": status.get("url", ""),
                "description": status.get("description", ""),
                "created_on": status.get("created_on", "")
            })

        # Calculate overall state
        if state_counts["FAILED"] > 0:
            overall_state = "FAILED"
        elif state_counts["INPROGRESS"] > 0:
            overall_state = "INPROGRESS"
        elif state_counts["STOPPED"] > 0:
            overall_state = "STOPPED"
        elif state_counts["SUCCESSFUL"] > 0:
            overall_state = "SUCCESSFUL"
        else:
            overall_state = "UNKNOWN"

        return {
            "pr_id": pr_id,
            "total_statuses": len(statuses),
            "overall_state": overall_state,
            "state_counts": state_counts,
            "statuses": formatted_statuses
        }

    except httpx.HTTPStatusError as e:
        if e.response.status_code == 404:
            return {"error": f"Pull request #{pr_id} not found"}
        return {"error": f"Failed to get PR build statuses: {sanitize_error(e)}"}


async def create_pull_request(
    title: str,
    source_branch: str,
    destination_branch: str,
    description: str = "",
    repo_slug: str = "",
) -> dict:
    """
    Create a new pull request

    Args:
        title: PR title (e.g., "feat: add pipeline invalidation warning")
        source_branch: Source branch name (e.g., "feature/pipeline-warning")
        destination_branch: Destination branch name (e.g., "develop")
        description: PR description in markdown (optional)
        repo_slug: Optional repo override (format: "workspace/repo-name")

    Returns:
        dict: Created PR details including ID and URL
    """
    client = get_client(repo_slug)

    try:
        pr = await client.create_pull_request(
            title=title,
            source_branch=source_branch,
            destination_branch=destination_branch,
            description=description
        )

        return {
            "success": True,
            "pr_id": pr.get("id"),
            "title": pr.get("title", ""),
            "state": pr.get("state", ""),
            "url": pr.get("links", {}).get("html", {}).get("href", ""),
            "source_branch": source_branch,
            "destination_branch": destination_branch,
            "author": pr.get("author", {}).get("display_name", ""),
            "created_on": pr.get("created_on", "")
        }

    except httpx.HTTPStatusError as e:
        error_detail = ""
        try:
            error_body = e.response.json()
            error_detail = error_body.get("error", {}).get("message", str(e))
        except Exception:
            error_detail = str(e)

        return {
            "success": False,
            "error": f"Failed to create PR: {error_detail}",
            "source_branch": source_branch,
            "destination_branch": destination_branch
        }


async def list_pipeline_schedules(repo_slug: str = "") -> dict:
    """
    List all configured pipeline schedules (cron-based triggers)

    Returns:
        dict: Pipeline schedules with cron patterns and target branches
    """
    client = get_client(repo_slug)

    try:
        schedules_response = await client.get_pipeline_schedules()
        schedules = schedules_response.get("values", [])

        formatted_schedules = []
        for schedule in schedules:
            formatted_schedules.append({
                "uuid": schedule.get("uuid", ""),
                "enabled": schedule.get("enabled", False),
                "cron_pattern": schedule.get("cron_pattern", ""),
                "target_branch": schedule.get("target", {}).get("ref_name", ""),
                "target_type": schedule.get("target", {}).get("ref_type", ""),
                "created_on": schedule.get("created_on", "")
            })

        return {
            "total_schedules": len(formatted_schedules),
            "schedules": formatted_schedules
        }

    except httpx.HTTPStatusError as e:
        return {"error": f"Failed to get pipeline schedules: {sanitize_error(e)}"}


async def get_pipeline_config(repo_slug: str = "") -> dict:
    """
    Get pipeline configuration for the repository

    Returns:
        dict: Pipeline configuration status and settings
    """
    client = get_client(repo_slug)

    try:
        config = await client.get_pipeline_configuration()

        return {
            "enabled": config.get("enabled", False),
            "type": config.get("type", ""),
            "has_pipelines": config.get("has_pipelines", False),
            "repository": {
                "name": config.get("repository", {}).get("name", ""),
                "full_name": config.get("repository", {}).get("full_name", "")
            }
        }

    except httpx.HTTPStatusError as e:
        return {"error": f"Failed to get pipeline configuration: {sanitize_error(e)}"}


async def get_ssh_key_info(repo_slug: str = "") -> dict:
    """
    Get pipeline SSH key pair information

    Returns:
        dict: SSH public key and fingerprint (private key never exposed)
    """
    client = get_client(repo_slug)

    try:
        ssh_keys = await client.get_pipeline_ssh_keys()

        # Extract key type and fingerprint from public key
        public_key = ssh_keys.get("public_key", "")
        key_parts = public_key.split() if public_key else []
        key_type = key_parts[0] if len(key_parts) > 0 else "unknown"

        return {
            "key_type": key_type,
            "public_key_preview": public_key[:100] + "..." if len(public_key) > 100 else public_key,
            "public_key_length": len(public_key),
            "private_key_sha256": ssh_keys.get("private_key_sha256", ""),
            "configured": True
        }

    except httpx.HTTPStatusError as e:
        if e.response.status_code == 404:
            return {
                "configured": False,
                "message": "No SSH key pair configured for pipelines"
            }
        return {"error": f"Failed to get SSH key info: {sanitize_error(e)}"}


# @mcp.tool() -- Removed: Hub handles registration
async def diagnose_pipeline_failure(
    build_number: int,
    step_name: str | None = None,
    *,
    use_ai: bool = False,
    repo_slug: str = "",
) -> dict:
    """
    🔍 HYBRID AI DIAGNOSIS: Analyze pipeline failure with pattern matching + contextual instructions

    **Sprint 6 - Phase 1-2: Hybrid Local + AI Enhancement (2025-01-04)**

    Features:
    - Pattern matching: Detects 8+ error categories (tests, deps, compilation, timeout, memory, network, permissions, docker)
    - Contextual guidance: Provides diagnostic questions, investigation paths, common causes, prevention tips
    - Auto-fix detection: Identifies if issue can be fixed automatically (config changes only)
    - Confidence scoring: 0.0-1.0 based on pattern match strength
    - **AI enhancement** (use_ai=True): FREE APIs (DeepSeek, Gemini, Mistral) validate and enrich local analysis
    - Estimated fix time: Based on error type and complexity

    Error Categories Detected:
    - test_failure: Unit test failures, assertion errors, JUnit/pytest failures
    - dependency_conflict: Maven/npm dependency resolution issues, missing artifacts
    - compilation_error: Java/TypeScript compilation failures, syntax errors
    - timeout: Step timeouts, exceeded time limits
    - memory_error: OutOfMemoryError, heap space issues
    - network_error: Connection refused, DNS failures, unreachable services
    - permission_denied: Authentication failures, access denied, expired tokens
    - docker_error: Docker image pull failures, build failures, daemon issues

    Args:
        build_number: Pipeline build number to diagnose
        step_name: Optional step name to analyze (auto-detects failed step if not provided)
        use_ai: Enable AI enhancement with FREE APIs (requires API keys: DEEPSEEK_API_KEY, GOOGLE_API_KEY, MISTRAL_API_KEY)
        repo_slug: Optional repo override (format: "workspace/repo-name")

    Returns:
        {
            "method": "hybrid_local",
            "build_number": 42,
            "step_name": "Build and Test",
            "branch": "feature/new-feature",
            "commit": "abc1234",
            "diagnosis": {
                "error_type": "test_failure",
                "severity": "high",
                "category": "testing",
                "confidence": 0.85,
                "matched_patterns": [
                    {"pattern": r"(\\d+) tests? failed", "line": "Tests run: 10, Failures: 3"}
                ],
                "root_cause_hypothesis": "Build failed due to test failure"
            },
            "immediate_actions": [
                "Review test logs above for specific assertion failures",
                "Check if test data fixtures are current",
                "Verify environment variables match test expectations"
            ],
            "diagnostic_questions": [
                "Are all test dependencies installed correctly?",
                "Has the test data changed recently?",
                "Are environment variables set correctly for tests?"
            ],
            "investigation_paths": [
                {
                    "path": "Check test logs",
                    "actions": [
                        "Locate the specific test class and method that failed",
                        "Review assertion error messages in detail",
                        "Check if test passes locally on your machine"
                    ]
                }
            ],
            "common_causes": [
                "Test data fixtures out of sync with code changes",
                "Flaky tests due to timing issues or random data",
                "Missing or incorrect environment variables"
            ],
            "prevention_tips": [
                "Run full test suite locally before pushing",
                "Use deterministic test data (avoid random values)",
                "Mock external dependencies to avoid network issues"
            ],
            "auto_fixable": false,
            "safety_level": "LOW",
            "estimated_fix_time": "15-30 minutes",
            "context": {
                "total_log_lines": 1234,
                "analysis_timestamp": "2025-01-04T12:34:56Z"
            }
        }

    Example:
        # Basic usage (auto-detects failed step)
        diagnose_pipeline_failure(build_number=42)

        # Specify step name
        diagnose_pipeline_failure(build_number=42, step_name="Build and Test")

    Use Cases:
    1. Quick diagnosis: Get instant feedback on what went wrong
    2. Learning: Understand common causes and prevention tips
    3. Planning: Use investigation paths to debug systematically
    4. Auto-fix detection: Identify safe fixes (config changes)

    Related Tools:
    - get_build_details: Get overall build status
    - get_step_logs: Get raw logs for manual review
    - auto_diagnose: Original diagnosis tool (being superseded)

    Notes:
    - LOCAL mode (use_ai=False, default): No external API calls (fast, free, privacy-safe)
    - AI-ENHANCED mode (use_ai=True): Context-enriched prompts to DeepSeek/Gemini/Mistral for validation
    - HIGH confidence (≥0.7): Pattern detected 3+ times in logs
    - MEDIUM confidence (0.3-0.7): Pattern detected 1-2 times → AI enhancement recommended
    - LOW confidence (<0.3): Unknown error, manual review needed
    - **Phase 2 ACTIVE**: AI-enhanced with FREE APIs (DeepSeek, Gemini, Mistral) via round-robin

    AI Enhancement Flow:
    1. Local analysis runs first (always)
    2. IF use_ai=True AND confidence < 0.8:
       - Call FREE APIs with context (local analysis + logs)
       - APIs validate local analysis and add insights
       - Merge results (local + AI)
    3. Return enhanced diagnosis

    Example with AI:
        diagnose_pipeline_failure(build_number=42, use_ai=True)
        → method: "hybrid_ai_enhanced"
        → ai_enhancement: {success: true, provider: "deepseek", tokens_used: 234}
        → additional_insights: ["AI-discovered insight 1", "..."]
    """
    try:
        from lib.bitbucket.client import BitbucketPipelineClient
        from lib.bitbucket.analyzer import PipelineAnalyzer

        client = get_client(repo_slug)
        analyzer = PipelineAnalyzer(client)

        # Choose method based on use_ai parameter
        if use_ai:
            result = await analyzer.diagnose_with_ai(
                build_number=build_number, step_name=step_name, use_api=True
            )
        else:
            result = await analyzer.diagnose_pipeline_failure(
                build_number=build_number, step_name=step_name
            )

        return result

    except Exception as e:
        return {
            "success": False,
            "error": f"Failed to diagnose build {build_number}: {sanitize_error(e)}",
            "build_number": build_number,
            "step_name": step_name,
        }


# @mcp.tool() -- Removed: Hub handles registration
async def save_successful_fix(
    build_number: int, solution_description: str, fix_type: str = "manual", repo_slug: str = ""
) -> dict:
    """
    💾 ADMIN TOOL: Save successful fix to knowledge base for auto-learning

    **Sprint 6 - Phase 3: Manual Auto-Learning (2025-01-04)**

    Use this tool after:
    1. Diagnosed failure with diagnose_pipeline_failure
    2. Applied fix manually (config change, dependency update, code fix)
    3. Verified new build succeeded

    The knowledge base will:
    - Store the error pattern and successful solution
    - Use fuzzy matching to find similar errors (85% threshold)
    - Track success/failure rate for confidence scoring
    - Suggest fixes automatically for similar future errors

    Args:
        build_number: Original failed build number (that you fixed)
        solution_description: What you did to fix it (free text, be specific)
        fix_type: "config" | "dependency" | "code" | "manual" (default: "manual")
        repo_slug: Optional repo override (format: "workspace/repo-name")

    Returns:
        {
            "success": true,
            "saved": true,
            "pattern_id": 123,
            "is_new_pattern": true/false,
            "similar_patterns_count": 2,
            "knowledge_base_stats": {
                "total_patterns": 47,
                "total_fixes_applied": 123,
                ...
            }
        }

    Example:
        # After fixing a memory error by increasing pipeline size
        save_successful_fix(
            build_number=42,
            solution_description="Increased memory from 1x to 2x in bitbucket-pipelines.yml",
            fix_type="config"
        )

        # After fixing dependency conflict
        save_successful_fix(
            build_number=43,
            solution_description="Updated spring-boot version from 2.7 to 3.0 in pom.xml",
            fix_type="dependency"
        )

    Related Tools:
    - search_learned_fixes: Search knowledge base for similar fixes
    - get_knowledge_base_stats: View overall KB statistics
    """
    try:
        from lib.bitbucket.knowledge_base import KnowledgeBase
        from lib.bitbucket.patterns import match_error_patterns
        from lib.bitbucket.client import BitbucketPipelineClient

        client = get_client(repo_slug)
        kb = KnowledgeBase()

        # Get original build to create error signature
        try:
            build = await client.get_pipeline(build_number)
        except Exception as e:
            return {
                "success": False,
                "error": f"Failed to fetch build {build_number}: {sanitize_error(e)}",
            }

        # Find failed step
        failed_step = None
        steps_data = await client.get_pipeline_steps(build_number)
        for step in steps_data.get("values", []):
            if step.get("state", {}).get("result", {}).get("name") == "FAILED":
                failed_step = step.get("name")
                break

        if not failed_step:
            return {
                "success": False,
                "error": "Build did not have a failed step",
                "suggestion": "Only save fixes for builds that actually failed",
            }

        # Get logs to create error signature
        try:
            logs_response = await client.get_step_logs(build_number, failed_step)
            logs = logs_response.get("logs", "")
        except Exception as e:
            return {
                "success": False,
                "error": f"Failed to fetch logs: {sanitize_error(e)}",
            }

        # Create error signature using pattern matching
        pattern_match = match_error_patterns(logs)
        error_type = pattern_match.get("error_type", "unknown")

        # Create unique signature (error_type + log hash)
        # Use MD5 for deterministic hashing (consistent across runs)
        log_hash = hashlib.md5(logs[:1000].encode('utf-8')).hexdigest()[:8]
        error_signature = f"{error_type}:{log_hash}"

        # Check if similar pattern exists
        similar_patterns = kb.search(error_signature)
        is_new = len(similar_patterns) == 0

        # Save to knowledge base
        kb.add_successful_fix(
            build_number=build_number,
            error_signature=error_signature,
            error_type=error_type,
            solution_applied={
                "description": solution_description,
                "fix_type": fix_type,
                "applied_by": "admin",
                "applied_at": datetime.now(timezone.utc).isoformat(),
            },
            metadata={
                "branch": build.get("target", {}).get("ref_name"),
                "commit": build.get("target", {}).get("commit", {}).get("hash"),
                "step_name": failed_step,
            },
        )

        stats = kb.get_stats()

        return {
            "success": True,
            "saved": True,
            "is_new_pattern": is_new,
            "similar_patterns_count": len(similar_patterns),
            "error_signature": error_signature,
            "error_type": error_type,
            "knowledge_base_stats": stats,
        }

    except Exception as e:
        return {
            "success": False,
            "error": f"Failed to save fix: {sanitize_error(e)}",
        }


# @mcp.tool() -- Removed: Hub handles registration
async def search_learned_fixes(
    error_description: str, min_confidence: float = 0.5
) -> dict:
    """
    🔍 ADMIN TOOL: Search knowledge base for similar fixes

    **Sprint 6 - Phase 3: Manual Auto-Learning (2025-01-04)**

    Search the knowledge base for similar errors and their successful fixes.
    Uses fuzzy matching (75% similarity threshold) to find related patterns.

    Args:
        error_description: Brief description of error (e.g., "memory error", "test failure", "timeout")
        min_confidence: Minimum confidence threshold (0.0-1.0, default: 0.5)

    Returns:
        {
            "found": 5,
            "patterns": [
                {
                    "id": 123,
                    "error_type": "memory_error",
                    "solutions": [
                        {
                            "description": "Increased memory from 1x to 2x",
                            "fix_type": "config",
                            "applied_by": "admin"
                        }
                    ],
                    "confidence": 0.95,
                    "success_count": 12,
                    "failure_count": 0,
                    "similarity": 0.87,
                    "last_used": "2025-01-04T12:00:00Z"
                },
                ...
            ],
            "knowledge_base_stats": {...}
        }

    Example:
        # Search for timeout-related fixes
        search_learned_fixes("timeout")

        # Search for test failures with high confidence only
        search_learned_fixes("test failure", min_confidence=0.8)

    Related Tools:
    - save_successful_fix: Add new fixes to knowledge base
    - get_knowledge_base_stats: View overall KB statistics
    """
    try:
        from lib.bitbucket.knowledge_base import KnowledgeBase

        kb = KnowledgeBase()
        results = kb.search(error_description, min_confidence=min_confidence)

        return {
            "found": len(results),
            "patterns": results[:10],  # Top 10
            "knowledge_base_stats": kb.get_stats(),
        }

    except Exception as e:
        return {
            "success": False,
            "error": f"Failed to search knowledge base: {sanitize_error(e)}",
        }


# @mcp.tool() -- Removed: Hub handles registration
async def get_knowledge_base_stats(repo_slug: str = "") -> dict:
    """
    📊 ADMIN TOOL: Get knowledge base statistics

    **Sprint 6 - Phase 3: Manual Auto-Learning (2025-01-04)**

    View comprehensive statistics about the auto-learning knowledge base:
    - Total patterns learned
    - Total fixes applied successfully
    - Average confidence score
    - Distribution by error type and fix type
    - Top 5 most successful solutions

    Returns:
        {
            "total_patterns": 47,
            "total_fixes_applied": 123,
            "average_confidence": 0.87,
            "error_type_distribution": {
                "test_failure": 15,
                "dependency_conflict": 12,
                "timeout": 10,
                "memory_error": 7,
                ...
            },
            "fix_type_distribution": {
                "config": 25,
                "dependency": 10,
                "code": 5,
                "manual": 7
            },
            "top_solutions": [
                {
                    "error_type": "timeout",
                    "solution": "Increase timeout in bitbucket-pipelines.yml",
                    "success_count": 12,
                    "confidence": 0.92
                },
                ...
            ],
            "knowledge_base_file": "/path/to/learned_patterns.json"
        }

    Example:
        get_knowledge_base_stats()
        
    Args:
        repo_slug: Accepted for API compatibility in multi-repo mode.
                   Currently unused because KB stats are global to the hub instance.

    Related Tools:
    - save_successful_fix: Add new fixes to knowledge base
    - search_learned_fixes: Search for similar fixes
    """
    _ = repo_slug
    try:
        from lib.bitbucket.knowledge_base import KnowledgeBase

        kb = KnowledgeBase()
        return kb.get_stats()

    except Exception as e:
        return {
            "success": False,
            "error": f"Failed to get KB stats: {sanitize_error(e)}",
        }


# ============================================================================
# PIPELINE TRIGGER & CONTROL TOOLS (Sprint 7)
# ============================================================================


async def trigger_pipeline(
    branch: str,
    custom_pipeline: str = "",
    variables: str = "",
    repo_slug: str = "",
) -> dict:
    """
    Trigger a pipeline on a specific branch

    Can trigger both automatic (branch-based) and custom (named) pipelines.
    Supports passing pipeline variables for dynamic configuration.

    Args:
        branch: Branch name to run pipeline on (e.g., "feature/my-feature/my-branch")
        custom_pipeline: Custom pipeline name from bitbucket-pipelines.yml (e.g., "deploy-preview"). Leave empty for default branch pipeline.
        variables: Comma-separated KEY=VALUE pairs (e.g., "DEPLOY_ENV=staging,VERSION=v1.0"). Leave empty for no extra variables.
        repo_slug: Optional repo override (format: "workspace/repo-name"). Defaults to current repo.

    Returns:
        dict: Pipeline trigger result with build_number, uuid, state, and URL
    """
    try:
        client = get_client(repo_slug)

        # Parse variables string into API format
        var_list = []
        if variables:
            for pair in variables.split(","):
                pair = pair.strip()
                if "=" in pair:
                    key, value = pair.split("=", 1)
                    var_list.append({"key": key.strip(), "value": value.strip(), "secured": False})

        result = await client.trigger_pipeline(
            ref_name=branch,
            custom_pipeline=custom_pipeline if custom_pipeline else None,
            variables=var_list if var_list else None,
        )

        return {
            "success": True,
            "build_number": result.get("build_number"),
            "uuid": result.get("uuid"),
            "state": result.get("state", {}).get("name", "PENDING"),
            "branch": branch,
            "custom_pipeline": custom_pipeline or "(default)",
            "variables_count": len(var_list),
            "url": f"https://bitbucket.org/{client.repo_slug}/pipelines/results/{result.get('build_number', '')}",
        }

    except httpx.HTTPStatusError as e:
        error_detail = ""
        try:
            error_body = e.response.json()
            error_detail = error_body.get("error", {}).get("message", str(e))
        except Exception:
            error_detail = str(e)
        return {"success": False, "error": f"Failed to trigger pipeline: {error_detail}"}

    except Exception as e:
        return {"success": False, "error": f"Failed to trigger pipeline: {sanitize_error(e)}"}


async def stop_pipeline(pipeline_uuid: str, repo_slug: str = "") -> dict:
    """
    Stop a running pipeline

    Args:
        pipeline_uuid: Pipeline UUID to stop (from trigger_pipeline or get_build_details)
        repo_slug: Optional repo override (format: "workspace/repo-name")

    Returns:
        dict: Stop result with status
    """
    try:
        client = get_client(repo_slug)
        result = await client.stop_pipeline(pipeline_uuid)
        return {"success": True, **result}

    except httpx.HTTPStatusError as e:
        error_detail = ""
        try:
            error_body = e.response.json()
            error_detail = error_body.get("error", {}).get("message", str(e))
        except Exception:
            error_detail = str(e)
        return {"success": False, "error": f"Failed to stop pipeline: {error_detail}"}

    except Exception as e:
        return {"success": False, "error": f"Failed to stop pipeline: {sanitize_error(e)}"}


async def list_branches(
    query: str = "",
    sort: str = "-target.date",
    count: int = 25,
    repo_slug: str = "",
) -> dict:
    """
    List branches in a Bitbucket repository

    Args:
        query: Filter branches by name pattern (e.g., "feature" to find feature/* branches). Uses Bitbucket CQL: name ~ "pattern"
        sort: Sort order. Options: "name", "-name", "-target.date" (default, most recent first)
        count: Number of branches to return (default: 25, max: 100)
        repo_slug: Optional repo override (format: "workspace/repo-name")

    Returns:
        dict: List of branches with name, commit hash, and last update
    """
    try:
        client = get_client(repo_slug)

        cql_query = f'name ~ "{query}"' if query else None
        result = await client.get_branches(query=cql_query, sort=sort, pagelen=min(count, 100))

        branches = []
        for b in result.get("values", []):
            branches.append({
                "name": b.get("name"),
                "commit": b.get("target", {}).get("hash", "")[:12],
                "date": b.get("target", {}).get("date", ""),
            })

        return {
            "branches": branches,
            "count": len(branches),
            "total": result.get("size", len(branches)),
            "repo": client.repo_slug,
        }

    except Exception as e:
        return {"success": False, "error": f"Failed to list branches: {sanitize_error(e)}"}


async def get_branch(branch_name: str, repo_slug: str = "") -> dict:
    """
    Get details about a specific branch

    Args:
        branch_name: Full branch name (e.g., "feature/my-feature/my-branch")
        repo_slug: Optional repo override (format: "workspace/repo-name")

    Returns:
        dict: Branch details including commit hash, merge strategies, and existence status
    """
    try:
        client = get_client(repo_slug)
        result = await client.get_branch(branch_name)

        return {
            "exists": True,
            "name": result.get("name"),
            "commit": result.get("target", {}).get("hash", ""),
            "commit_short": result.get("target", {}).get("hash", "")[:12],
            "merge_strategies": result.get("merge_strategies", []),
            "default_merge_strategy": result.get("default_merge_strategy", ""),
            "url": f"https://bitbucket.org/{client.repo_slug}/branch/{branch_name}",
        }

    except httpx.HTTPStatusError as e:
        if e.response.status_code == 404:
            return {"exists": False, "name": branch_name, "error": "Branch not found"}
        return {"exists": False, "error": f"Failed to get branch: {str(e)}"}

    except Exception as e:
        return {"exists": False, "error": f"Failed to get branch: {sanitize_error(e)}"}


# ============================================================================
# TOOL REGISTRY
# ============================================================================

TOOLS = {
    # Core tools
    "get_recent_builds": get_recent_builds,
    "get_build_details": get_build_details,
    "get_build_steps": get_build_steps,
    "get_step_logs": get_step_logs,
    # Analysis tools
    "analyze_failures": analyze_failures,
    "auto_diagnose": auto_diagnose,
    "compare_builds": compare_builds,
    "diagnose_pipeline_failure": diagnose_pipeline_failure,  # Sprint 6 Phase 1 (2025-01-04)
    # Health tools
    "check_pipeline_health": check_pipeline_health,
    "check_alerts": check_alerts,
    "get_executive_summary": get_executive_summary,
    # Test Reports tools (Sprint 1 - 2025-10-31)
    "get_test_reports": get_test_reports,
    "get_test_cases": get_test_cases,
    "get_test_case_reasons": get_test_case_reasons,
    # Deployments & Variables tools (Sprint 2 - 2025-10-31)
    "get_recent_deployments": get_recent_deployments,
    "get_deployment_details": get_deployment_details,
    "get_environments": get_environments,
    "get_environment_variables": get_environment_variables,
    "get_repository_variables": get_repository_variables,
    "get_workspace_variables": get_workspace_variables,
    # Cache Management tools (Sprint 3 - 2025-10-31)
    "list_caches": list_caches,
    "get_cache_details": get_cache_details,
    "clear_cache": clear_cache,
    "analyze_cache_efficiency": analyze_cache_efficiency,
    # Commits & Build Status tools (Sprint 4 - 2025-10-31)
    "get_commit_details": get_commit_details,
    "get_commit_build_statuses": get_commit_build_statuses,
    "get_builds_for_commit": get_builds_for_commit,
    "compare_commit_builds": compare_commit_builds,
    # Pull Requests & Configuration tools (Sprint 5 - 2025-10-31)
    "get_pull_requests": get_pull_requests,
    "get_pr_details": get_pr_details,
    "get_pr_build_statuses": get_pr_build_statuses,
    "create_pull_request": create_pull_request,  # Sprint 7 - 2026-02-06 (Eko autonomy)
    "list_pipeline_schedules": list_pipeline_schedules,
    "get_pipeline_config": get_pipeline_config,
    "get_ssh_key_info": get_ssh_key_info,
    # Auto-Learning tools (Sprint 6 Phase 3 - 2025-01-04)
    "save_successful_fix": save_successful_fix,
    "search_learned_fixes": search_learned_fixes,
    "get_knowledge_base_stats": get_knowledge_base_stats,
    # Pipeline Trigger & Control tools (Sprint 7)
    "trigger_pipeline": trigger_pipeline,
    "stop_pipeline": stop_pipeline,
    "list_branches": list_branches,
    "get_branch": get_branch,
}
