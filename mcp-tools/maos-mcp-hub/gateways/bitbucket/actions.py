"""
Bitbucket gateway actions — maps 52 existing tools into resource+operation taxonomy.

All handlers are imported from servers/bitbucket/tools.py (zero rewrite).
The RESOURCE_MAP defines the hierarchical structure exposed to agents.
"""

from servers.bitbucket.tools import TOOLS as BB_TOOLS

from lib.gateway.router import MetaToolRouter

from .gateway import GATEWAY_INFO

# ---------------------------------------------------------------------------
# Resource → Operation mapping (52 tools → 11 resources)
# ---------------------------------------------------------------------------

RESOURCE_MAP = {
    "pipeline": {
        "list": BB_TOOLS["get_recent_builds"],
        "get": BB_TOOLS["get_build_details"],
        "get_steps": BB_TOOLS["get_build_steps"],
        "get_logs": BB_TOOLS["get_step_logs"],
        "trigger": BB_TOOLS["trigger_pipeline"],
        "stop": BB_TOOLS["stop_pipeline"],
        "get_config": BB_TOOLS["get_pipeline_config"],
        "get_schedules": BB_TOOLS["list_pipeline_schedules"],
        "get_health": BB_TOOLS["check_pipeline_health"],
        "get_alerts": BB_TOOLS["check_alerts"],
        "get_summary": BB_TOOLS["get_executive_summary"],
        "get_ssh_key": BB_TOOLS["get_ssh_key_info"],
        "analyze_failures": BB_TOOLS["analyze_failures"],
        "diagnose": BB_TOOLS["diagnose_pipeline_failure"],
        "auto_diagnose": BB_TOOLS["auto_diagnose"],
        "compare": BB_TOOLS["compare_builds"],
    },
    "pull_request": {
        "list": BB_TOOLS["get_pull_requests"],
        "get": BB_TOOLS["get_pr_details"],
        "create": BB_TOOLS["create_pull_request"],
        "merge": BB_TOOLS["merge_pull_request"],
        "approve": BB_TOOLS["approve_pull_request"],
        "unapprove": BB_TOOLS["unapprove_pull_request"],
        "get_comments": BB_TOOLS["get_pr_comments"],
        "get_build_statuses": BB_TOOLS["get_pr_build_statuses"],
    },
    "branch": {
        "list": BB_TOOLS["list_branches"],
        "get": BB_TOOLS["get_branch"],
        "create": BB_TOOLS["create_branch"],
        "delete": BB_TOOLS["delete_branch"],
        "set_default": BB_TOOLS["set_default_branch"],
        "get_restrictions": BB_TOOLS["get_branch_restrictions"],
        "set_restriction": BB_TOOLS["set_branch_restriction"],
        "delete_restriction": BB_TOOLS["delete_branch_restriction"],
    },
    "deployment": {
        "list": BB_TOOLS["get_recent_deployments"],
        "get": BB_TOOLS["get_deployment_details"],
        "get_environments": BB_TOOLS["get_environments"],
        "get_env_variables": BB_TOOLS["get_environment_variables"],
    },
    "commit": {
        "get": BB_TOOLS["get_commit_details"],
        "get_build_statuses": BB_TOOLS["get_commit_build_statuses"],
        "get_builds": BB_TOOLS["get_builds_for_commit"],
        "compare_builds": BB_TOOLS["compare_commit_builds"],
    },
    "test": {
        "get_reports": BB_TOOLS["get_test_reports"],
        "get_cases": BB_TOOLS["get_test_cases"],
        "get_case_reasons": BB_TOOLS["get_test_case_reasons"],
    },
    "cache": {
        "list": BB_TOOLS["list_caches"],
        "get": BB_TOOLS["get_cache_details"],
        "clear": BB_TOOLS["clear_cache"],
        "analyze_efficiency": BB_TOOLS["analyze_cache_efficiency"],
    },
    "variable": {
        "get_repository": BB_TOOLS["get_repository_variables"],
        "get_workspace": BB_TOOLS["get_workspace_variables"],
    },
    "learning": {
        "save_fix": BB_TOOLS["save_successful_fix"],
        "search_fixes": BB_TOOLS["search_learned_fixes"],
        "get_stats": BB_TOOLS["get_knowledge_base_stats"],
    },
}

# ---------------------------------------------------------------------------
# Governance rules by resource (from OSPPE Exp 16 crossref)
# ---------------------------------------------------------------------------

_GOVERNANCE = {
    "pull_request": {
        "create": [
            "Jira key obrigatorio no titulo",
            "governance_level obrigatorio no body",
            "Aguardar review de 3+ bots: CodeRabbit, Qodo, Copilot, RovoDev (1-3 min cada)",
            "Verificar se Copilot SWE Agent pushiou autofix na branch (governance risk)",
        ],
        "merge": [
            "Pipeline deve estar green",
            "Minimo 1 approver",
            "SECURITY_AUDIT obrigatorio se risk_score >= 3",
            "Todos os PR review comments devem estar RESOLVED (aceitos, rejeitados com justificativa, ou deferred)",
            "Bot scorecard preenchido como comentario no PR",
        ],
        "approve": [
            "Approver nao pode ser o autor",
            "Verificar que todos os findings aceitos foram implementados",
            "Verificar que findings rejeitados tem justificativa documentada no PR",
            "Se 2+ bots concordam num finding nao resolvido — NAO aprovar",
        ],
        "get_comments": [
            "Ativar 7 mentes para analise: critica, tome, suspicious, curiosa, sistemica, resolutiva, retrospectiva",
            "Consenso 2+ bots = quase certamente bug real — priorizar",
            "CodeRabbit 'duplicates' sao reminders intencionais, nao novos findings",
        ],
        "get": [
            "Verificar contagem de commits — se houver commit de bot (copilot-swe-agent) investigar diff",
            "Comparar reviewers presentes vs bots esperados (CodeRabbit, Qodo, Copilot, RovoDev)",
        ],
    },
    "branch": {
        "create": ["Branch naming regex: feature/|bugfix/|hotfix/|release/"],
    },
    "pipeline": {
        "get_logs": ["Verificar ausencia de secrets/PII nos logs"],
    },
}

_NEXT_STEPS = {
    "pull_request": {
        "create": [
            "Acionar bots: @coderabbitai review, /review, @copilot review",
            "Verificar pipeline status",
            "Ativar 7 mentes antes de analisar cada comment",
        ],
        "merge": [
            "Atualizar Jira ticket status (transicao + comentario com evidencia)",
            "Verificar deployment",
            "Inventariar e atualizar documentacao relacionada",
        ],
        "get_comments": [
            "Para cada comment: ACEITAR / REJEITAR / DEFER com justificativa",
            "Se bot pushiou commit automatico — verificar diff antes de prosseguir",
            "Atualizar bot scorecard (precisao por bot)",
        ],
        "approve": [
            "Postar comentario de aprovacao com resumo dos findings",
        ],
        "get": [
            "Se CI failing — diagnosticar antes de analisar reviews",
            "Se CHANGES_REQUESTED — ler comments com 7 mentes ativadas",
        ],
    },
    "branch": {
        "create": ["Criar pull request apos implementacao"],
    },
}


# ---------------------------------------------------------------------------
# Router builder
# ---------------------------------------------------------------------------

def build_router() -> MetaToolRouter:
    """Build the Bitbucket meta-tool router with all 52 actions."""
    router = MetaToolRouter(
        tool_name=GATEWAY_INFO["tool_name"],
        governance=["Bitbucket operations follow S-SDLC governance"],
    )

    for resource, operations in RESOURCE_MAP.items():
        res_gov = _GOVERNANCE.get(resource, {})
        res_next = _NEXT_STEPS.get(resource, {})

        for operation, handler in operations.items():
            router.register(
                resource=resource,
                operation=operation,
                handler=handler,
                governance=res_gov.get(operation),
                next_steps=res_next.get(operation),
            )

    return router
