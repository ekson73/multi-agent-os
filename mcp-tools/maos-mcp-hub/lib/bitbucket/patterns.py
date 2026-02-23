"""
Pattern Matching Engine for Pipeline Failure Diagnosis

Detects error patterns in build logs and suggests solutions.
Supports 6 main error categories with regex-based detection.

Author: MAOS MCP Hub
Version: 1.0.0
"""

import re
from typing import Dict, List, Optional


ERROR_PATTERNS = {
    "test_failure": {
        "patterns": [
            r"(\d+) tests? failed",
            r"AssertionError",
            r"junit.*FAILED",
            r"pytest.*FAILED",
            r"Test.*failed",
            r"FAILED.*tests?",
            r"Test suite failed",
            r"mvn.*test.*FAILURE",
            r"npm test.*failed",
            r"\d+ failing"
        ],
        "severity": "high",
        "category": "testing",
        "solutions": [
            {
                "type": "investigation",
                "priority": "immediate",
                "steps": [
                    "Review test logs above for specific assertion failures",
                    "Check if test data fixtures are current",
                    "Verify environment variables match test expectations",
                    "Confirm database schema is up to date",
                    "Check if tests pass locally"
                ],
                "auto_fixable": False,
                "safety": "LOW"
            }
        ]
    },
    "dependency_conflict": {
        "patterns": [
            r"Could not find.*dependency",
            r"Failed to resolve.*artifact",
            r"Conflict.*version",
            r"maven.*dependency.*not found",
            r"npm ERR! peer dep missing",
            r"No matching version found",
            r"Unable to download artifact",
            r"Dependency.*resolution failed",
            r"package.*not found",
            r"Could not resolve dependencies"
        ],
        "severity": "high",
        "category": "dependencies",
        "solutions": [
            {
                "type": "config_fix",
                "priority": "high",
                "steps": [
                    "Check pom.xml/package.json for version conflicts",
                    "Verify artifact repository is accessible (Maven Central, npm registry)",
                    "Try clearing dependency cache",
                    "Run dependency tree analysis: mvn dependency:tree or npm ls",
                    "Check for transitive dependency conflicts"
                ],
                "auto_fixable": True,
                "safety": "HIGH",
                "auto_fix_action": "clear_cache"
            }
        ]
    },
    "compilation_error": {
        "patterns": [
            r"compilation failed",
            r"cannot find symbol",
            r"package.*does not exist",
            r"SyntaxError",
            r"TypeScript error TS\d+",
            r"javac.*error",
            r"Compilation failure",
            r"error: invalid syntax",
            r"error TS\d+:",
            r"BUILD FAILURE.*compilation"
        ],
        "severity": "critical",
        "category": "compilation",
        "solutions": [
            {
                "type": "code_review",
                "priority": "immediate",
                "steps": [
                    "Review compilation errors in logs above",
                    "Check for missing imports or packages",
                    "Verify all source files are committed",
                    "Confirm Java/Node version matches project requirements",
                    "Check if annotation processors ran correctly"
                ],
                "auto_fixable": False,
                "safety": "LOW"
            }
        ]
    },
    "timeout": {
        "patterns": [
            r"timeout",
            r"exceeded.*time limit",
            r"killed.*minutes",
            r"step timed out",
            r"Timeout after \d+ minutes",
            r"max-time exceeded",
            r"Build timed out",
            r"execution timed out",
            r"SIGTERM.*timeout"
        ],
        "severity": "medium",
        "category": "performance",
        "solutions": [
            {
                "type": "config_fix",
                "priority": "high",
                "steps": [
                    "Increase step timeout in bitbucket-pipelines.yml (max-time property)",
                    "Optimize build by enabling parallel execution",
                    "Consider splitting long-running tests into separate steps",
                    "Check for hanging processes or infinite loops"
                ],
                "auto_fixable": True,
                "safety": "HIGH",
                "auto_fix_action": "increase_timeout",
                "config_change": {
                    "file": "bitbucket-pipelines.yml",
                    "property": "max-time",
                    "suggestion": "Increase by 50%"
                }
            }
        ]
    },
    "memory_error": {
        "patterns": [
            r"OutOfMemoryError",
            r"heap space",
            r"Allocation failed",
            r"memory exceeded",
            r"Cannot allocate memory",
            r"Java heap space",
            r"GC overhead limit exceeded",
            r"Fatal error.*memory",
            r"killed.*OOM",
            r"out of memory"
        ],
        "severity": "high",
        "category": "resources",
        "solutions": [
            {
                "type": "config_fix",
                "priority": "high",
                "steps": [
                    "Increase step memory in bitbucket-pipelines.yml (size: 2x property)",
                    "Check for memory leaks in tests or application code",
                    "Reduce parallel test execution to lower memory usage",
                    "Increase JVM heap size (-Xmx parameter)"
                ],
                "auto_fixable": True,
                "safety": "HIGH",
                "auto_fix_action": "increase_memory",
                "config_change": {
                    "file": "bitbucket-pipelines.yml",
                    "property": "size",
                    "suggestion": "Upgrade from 1x to 2x"
                }
            }
        ]
    },
    "network_error": {
        "patterns": [
            r"Connection.*refused",
            r"Could not connect",
            r"network.*unreachable",
            r"DNS resolution failed",
            r"Connection timed out",
            r"No route to host",
            r"Unable to reach",
            r"Network is unreachable",
            r"Failed to connect to",
            r"Connection reset"
        ],
        "severity": "medium",
        "category": "network",
        "solutions": [
            {
                "type": "retry",
                "priority": "medium",
                "steps": [
                    "Retry the build (transient network issue is common)",
                    "Check if external service is down (Maven Central, npm registry, etc.)",
                    "Verify firewall rules allow outbound connections",
                    "Check if VPN or proxy configuration is required",
                    "Verify DNS resolution is working"
                ],
                "auto_fixable": False,
                "safety": "MEDIUM"
            }
        ]
    },
    "permission_denied": {
        "patterns": [
            r"Permission denied",
            r"Access denied",
            r"Forbidden",
            r"401 Unauthorized",
            r"403 Forbidden",
            r"Authentication failed",
            r"Invalid credentials",
            r"Access token.*expired",
            r"Not authorized"
        ],
        "severity": "high",
        "category": "security",
        "solutions": [
            {
                "type": "config_fix",
                "priority": "high",
                "steps": [
                    "Check repository/deployment variables for correct credentials",
                    "Verify access tokens have not expired",
                    "Confirm service account has necessary permissions",
                    "Check if SSH keys are properly configured",
                    "Verify artifact repository credentials in settings"
                ],
                "auto_fixable": False,
                "safety": "MEDIUM"
            }
        ]
    },
    "docker_error": {
        "patterns": [
            r"docker.*error",
            r"Cannot connect to Docker daemon",
            r"docker.*failed",
            r"image.*not found",
            r"manifest.*not found",
            r"no space left on device",
            r"Docker build failed",
            r"pull access denied"
        ],
        "severity": "high",
        "category": "docker",
        "solutions": [
            {
                "type": "investigation",
                "priority": "high",
                "steps": [
                    "Check if Docker image name and tag are correct",
                    "Verify Docker Hub credentials if using private images",
                    "Check if Docker daemon is running",
                    "Verify sufficient disk space is available",
                    "Check if base image exists in registry"
                ],
                "auto_fixable": False,
                "safety": "MEDIUM"
            }
        ]
    }
}


def match_error_patterns(logs: str) -> Dict:
    """
    Match error patterns in build logs.

    Analyzes logs using regex patterns to identify error categories.
    Returns the highest confidence match with suggested solutions.

    Args:
        logs: Raw build logs as string

    Returns:
        {
            "matched": bool,
            "error_type": str,
            "severity": str,
            "category": str,
            "confidence": float (0.0-1.0),
            "matches": [{"pattern": str, "line": str}],
            "solutions": [...]
        }

    Examples:
        >>> logs = "BUILD FAILURE\\nTests run: 10, Failures: 3"
        >>> result = match_error_patterns(logs)
        >>> result["error_type"]
        'test_failure'
        >>> result["confidence"]
        0.67
    """
    results = []

    for error_type, config in ERROR_PATTERNS.items():
        matches = []

        for pattern in config["patterns"]:
            for line in logs.split("\n"):
                if re.search(pattern, line, re.IGNORECASE):
                    matches.append({
                        "pattern": pattern,
                        "line": line.strip()
                    })

        if matches:
            # Confidence based on number of pattern matches
            # 1 match = 0.33, 2 matches = 0.67, 3+ matches = 1.0
            confidence = min(len(matches) / 3.0, 1.0)

            results.append({
                "error_type": error_type,
                "severity": config["severity"],
                "category": config["category"],
                "confidence": confidence,
                "matches": matches[:5],  # Top 5 matches
                "solutions": config["solutions"]
            })

    if results:
        # Return highest confidence match
        best_match = max(results, key=lambda x: x["confidence"])
        return {
            "matched": True,
            **best_match
        }

    # No patterns matched
    return {
        "matched": False,
        "error_type": "unknown",
        "severity": "unknown",
        "category": "unknown",
        "confidence": 0.0,
        "matches": [],
        "solutions": []
    }


def get_error_pattern_config(error_type: str) -> Optional[Dict]:
    """
    Get configuration for specific error type.

    Args:
        error_type: Error type key (e.g., "test_failure")

    Returns:
        Error configuration dict or None if not found

    Example:
        >>> config = get_error_pattern_config("test_failure")
        >>> config["severity"]
        'high'
    """
    return ERROR_PATTERNS.get(error_type)


def list_all_error_types() -> List[str]:
    """
    Get list of all supported error types.

    Returns:
        List of error type keys

    Example:
        >>> types = list_all_error_types()
        >>> "test_failure" in types
        True
    """
    return list(ERROR_PATTERNS.keys())


def get_auto_fixable_errors() -> List[str]:
    """
    Get list of error types that can be auto-fixed.

    Returns:
        List of auto-fixable error types

    Example:
        >>> fixable = get_auto_fixable_errors()
        >>> "dependency_conflict" in fixable
        True
    """
    fixable = []

    for error_type, config in ERROR_PATTERNS.items():
        for solution in config["solutions"]:
            if solution.get("auto_fixable", False):
                fixable.append(error_type)
                break

    return fixable


def get_high_safety_auto_fixes() -> List[str]:
    """
    Get error types with HIGH safety auto-fixes.

    Returns:
        List of error types with safe auto-fixes

    Example:
        >>> safe_fixes = get_high_safety_auto_fixes()
        >>> "timeout" in safe_fixes
        True
    """
    safe = []

    for error_type, config in ERROR_PATTERNS.items():
        for solution in config["solutions"]:
            if solution.get("auto_fixable") and solution.get("safety") == "HIGH":
                safe.append(error_type)
                break

    return safe
