"""
Bitbucket Pipeline Monitor - Server Metadata
"""

SERVER_INFO = {
    "name": "bitbucket",
    "display_name": "Bitbucket Pipeline Monitor",
    "version": "2.0.0",
    "description": "Monitor, trigger, and analyze Bitbucket Cloud pipelines with AI-powered diagnosis, auto-learning, deployments, variables, caches, commits, PRs, and branch management. Supports Basic/Bearer auth and multi-repo.",
    "mcp_server": "hub.py",
    "env_vars": {
        "BITBUCKET_EMAIL": "Atlassian account email (preferred for Basic auth with API token)",
        "JIRA_EMAIL": "(Optional) Shared fallback email for Basic auth principal",
        "BITBUCKET_USERNAME": "Bitbucket username (legacy/basic fallback)",
        "BITBUCKET_API_TOKEN": "Bitbucket API token (primary variable)",
        "BITBUCKET_APP_PASSWORD": "(Legacy alias) old app-password or bearer token (ATCTT3x...)",
        "BITBUCKET_REPO_SLUG": "(Optional) Override repo slug (workspace/repo-name)",
        "BITBUCKET_AUTH_TYPE": "(Optional) Force auth type: 'bearer' or 'basic'",
        "DEEPSEEK_API_KEY": "(Optional) DeepSeek AI API key for enhanced diagnosis",
        "GOOGLE_API_KEY": "(Optional) Google Gemini API key for enhanced diagnosis",
        "MISTRAL_API_KEY": "(Optional) Mistral Codestral API key for enhanced diagnosis"
    },
    "tools": [
        # Core Pipeline Tools
        "get_recent_builds",
        "get_build_details",
        "get_build_steps",
        "get_step_logs",
        # Analysis & Diagnostics Tools
        "analyze_failures",
        "auto_diagnose",
        "compare_builds",
        "diagnose_pipeline_failure",
        # Health & Monitoring Tools
        "check_pipeline_health",
        "check_alerts",
        "get_executive_summary",
        # Test Reports Tools (Sprint 1)
        "get_test_reports",
        "get_test_cases",
        "get_test_case_reasons",
        # Deployments & Variables Tools (Sprint 2)
        "get_recent_deployments",
        "get_deployment_details",
        "get_environments",
        "get_environment_variables",
        "get_repository_variables",
        "get_workspace_variables",
        # Cache Management Tools (Sprint 3)
        "list_caches",
        "get_cache_details",
        "clear_cache",
        "analyze_cache_efficiency",
        # Commits & Build Status Tools (Sprint 4)
        "get_commit_details",
        "get_commit_build_statuses",
        "get_builds_for_commit",
        "compare_commit_builds",
        # Pull Requests & Configuration Tools (Sprint 5)
        "get_pull_requests",
        "get_pr_details",
        "get_pr_build_statuses",
        "create_pull_request",
        "list_pipeline_schedules",
        "get_pipeline_config",
        "get_ssh_key_info",
        # Auto-Learning Tools (Sprint 6 Phase 3)
        "save_successful_fix",
        "search_learned_fixes",
        "get_knowledge_base_stats",
        # Pipeline Trigger & Branch Tools (Sprint 7)
        "trigger_pipeline",
        "stop_pipeline",
        "list_branches",
        "get_branch",
    ]
}
