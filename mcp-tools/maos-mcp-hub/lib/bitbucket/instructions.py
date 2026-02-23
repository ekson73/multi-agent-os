"""
Contextual Instruction Templates for Pipeline Failure Diagnosis

Provides diagnostic questions, investigation paths, and prevention tips
to complement pattern matching with human guidance.

Author: MAOS MCP Hub
Version: 1.0.0
"""

from typing import Dict, List


INSTRUCTION_TEMPLATES = {
    "test_failure": {
        "diagnostic_questions": [
            "Are all test dependencies installed correctly?",
            "Has the test data changed recently?",
            "Are environment variables set correctly for tests?",
            "Is the database schema up to date with migrations?",
            "Are there any flaky tests that need investigation?",
            "Did recent code changes break test assumptions?",
            "Are mock services responding correctly?"
        ],
        "investigation_paths": [
            {
                "path": "Check test logs",
                "actions": [
                    "Locate the specific test class and method that failed",
                    "Review assertion error messages in detail",
                    "Check if test passes locally on your machine",
                    "Look for timing issues or race conditions"
                ]
            },
            {
                "path": "Verify test environment",
                "actions": [
                    "Confirm test database is accessible and initialized",
                    "Verify mock services are running and accessible",
                    "Check test fixture data is loaded correctly",
                    "Ensure environment variables match test expectations"
                ]
            },
            {
                "path": "Review recent changes",
                "actions": [
                    "Check commits since last successful build",
                    "Identify changes to tested code or test itself",
                    "Review changes to test data or fixtures",
                    "Check for changes to test configuration"
                ]
            }
        ],
        "common_causes": [
            "Test data fixtures out of sync with code changes",
            "Flaky tests due to timing issues or random data",
            "Missing or incorrect environment variables",
            "Database migrations not applied in test environment",
            "External service dependencies unavailable or mocked incorrectly",
            "Assertion expectations changed but test not updated",
            "Parallel test execution causing resource conflicts"
        ],
        "prevention_tips": [
            "Run full test suite locally before pushing",
            "Use deterministic test data (avoid random values)",
            "Mock external dependencies to avoid network issues",
            "Implement retry logic for known flaky tests",
            "Keep test data fixtures in sync with schema",
            "Use test containers for consistent database state",
            "Add test coverage for edge cases"
        ],
        "related_docs": [
            "https://junit.org/junit5/docs/current/user-guide/",
            "https://docs.pytest.org/en/stable/",
            "https://martinfowler.com/articles/practical-test-pyramid.html"
        ]
    },
    "dependency_conflict": {
        "diagnostic_questions": [
            "Was a dependency version recently changed in pom.xml or package.json?",
            "Are all artifact repositories accessible (Maven Central, JFrog, npm registry)?",
            "Is the dependency cache corrupted?",
            "Are there transitive dependency conflicts?",
            "Is the dependency published to the correct repository?",
            "Do credentials for private repositories still work?",
            "Is the network connection stable?"
        ],
        "investigation_paths": [
            {
                "path": "Review dependency changes",
                "actions": [
                    "Check recent commits for pom.xml/package.json changes",
                    "Run dependency tree analysis: mvn dependency:tree or npm ls",
                    "Look for version conflicts in transitive dependencies",
                    "Check if new dependency introduced conflicts"
                ]
            },
            {
                "path": "Check repository access",
                "actions": [
                    "Verify Maven Central / npm registry is accessible",
                    "Check JFrog Artifactory credentials and permissions",
                    "Test repository URL connectivity with curl",
                    "Verify proxy settings if behind corporate firewall"
                ]
            },
            {
                "path": "Clear caches",
                "actions": [
                    "Clear Maven local cache: rm -rf ~/.m2/repository",
                    "Clear npm cache: npm cache clean --force",
                    "Clear Bitbucket pipeline caches via API or UI",
                    "Retry build after cache clear"
                ]
            }
        ],
        "common_causes": [
            "Version conflict between direct and transitive dependencies",
            "Repository unreachable or credentials expired",
            "Corrupted local or pipeline cache",
            "Dependency not yet published to repository",
            "Network timeout during dependency download",
            "Incorrect repository URL in configuration",
            "Snapshot dependency changed without version bump"
        ],
        "prevention_tips": [
            "Use dependency lock files (package-lock.json, maven-enforcer)",
            "Pin dependency versions explicitly (avoid LATEST or ranges)",
            "Monitor dependency repository health and status",
            "Use dependency vulnerability scanning",
            "Document private repository credentials in team wiki",
            "Set up repository mirrors for high availability"
        ],
        "related_docs": [
            "https://maven.apache.org/guides/introduction/introduction-to-dependency-mechanism.html",
            "https://docs.npmjs.com/cli/v8/commands/npm-install",
            "https://github.com/npm/cli/blob/latest/docs/content/using-npm/dependency-resolution.md"
        ]
    },
    "compilation_error": {
        "diagnostic_questions": [
            "Were there recent code changes that could cause compilation errors?",
            "Are all source files committed to the repository?",
            "Is the Java/Node/TypeScript version correct for this project?",
            "Are generated sources (Lombok, annotation processors) up to date?",
            "Are there missing imports or incorrect package declarations?",
            "Is the build tool version compatible (Maven, npm, tsc)?"
        ],
        "investigation_paths": [
            {
                "path": "Review compilation errors",
                "actions": [
                    "Locate the exact file and line number with error",
                    "Check for missing imports or incorrect package names",
                    "Verify method signatures match usage",
                    "Look for typos or syntax errors"
                ]
            },
            {
                "path": "Verify build environment",
                "actions": [
                    "Confirm Java/Node/TypeScript version matches requirements",
                    "Check if annotation processors ran correctly (Lombok, etc.)",
                    "Verify generated sources exist in target directory",
                    "Ensure compiler flags are correct"
                ]
            },
            {
                "path": "Check recent changes",
                "actions": [
                    "Review commits since last successful build",
                    "Identify new files or changes to existing files",
                    "Check for refactoring that broke dependencies",
                    "Verify all imports are resolvable"
                ]
            }
        ],
        "common_causes": [
            "Syntax errors in code (typos, missing semicolons, etc.)",
            "Missing imports or incorrect import paths",
            "Type mismatches or incorrect generics",
            "Generated code not created (annotation processors failed)",
            "Wrong compiler version (Java 11 code with Java 8 compiler)",
            "Lombok or other code generation not running",
            "Circular dependencies between modules"
        ],
        "prevention_tips": [
            "Enable strict compilation warnings locally",
            "Use IDE linting and error checking before commit",
            "Run full build locally before pushing (mvn clean install)",
            "Set up pre-commit hooks to catch compilation errors",
            "Use static analysis tools (Checkstyle, ESLint)",
            "Configure IDE to match project compiler settings"
        ],
        "related_docs": [
            "https://docs.oracle.com/en/java/javase/11/tools/javac.html",
            "https://www.typescriptlang.org/docs/handbook/compiler-options.html",
            "https://projectlombok.org/features/"
        ]
    },
    "timeout": {
        "diagnostic_questions": [
            "How long does this step normally take?",
            "Has the build become slower recently?",
            "Are there long-running tests that could be optimized?",
            "Is the step waiting on external resources?",
            "Are there hanging processes or infinite loops?",
            "Is the timeout setting too aggressive?"
        ],
        "investigation_paths": [
            {
                "path": "Analyze build performance",
                "actions": [
                    "Review logs to see where build gets stuck",
                    "Compare build times with previous successful builds",
                    "Identify slowest tests or build steps",
                    "Check for network waits or external service calls"
                ]
            },
            {
                "path": "Optimize build process",
                "actions": [
                    "Enable parallel test execution",
                    "Split long-running tests into separate steps",
                    "Use build caching for dependencies",
                    "Skip unnecessary steps (e.g., integration tests on feature branches)"
                ]
            },
            {
                "path": "Increase timeout",
                "actions": [
                    "Edit bitbucket-pipelines.yml",
                    "Increase max-time property for slow step",
                    "Document why timeout needs to be higher",
                    "Monitor if increase is sufficient"
                ]
            }
        ],
        "common_causes": [
            "Step timeout set too low for actual execution time",
            "Build performance degraded due to more tests or code",
            "Network latency when downloading dependencies",
            "Hanging test waiting for external service",
            "Infinite loop or deadlock in code",
            "Resource contention (CPU, memory) slowing execution"
        ],
        "prevention_tips": [
            "Set realistic timeout values based on average execution time + 50%",
            "Monitor build performance trends over time",
            "Optimize slow tests or split into separate jobs",
            "Use build caching to speed up dependency downloads",
            "Run integration tests only on specific branches",
            "Profile slow tests to find optimization opportunities"
        ],
        "related_docs": [
            "https://support.atlassian.com/bitbucket-cloud/docs/configure-bitbucket-pipelinesyml/",
            "https://confluence.atlassian.com/bitbucket/build-configuration-reference-788285764.html"
        ]
    },
    "memory_error": {
        "diagnostic_questions": [
            "How much memory does this step normally use?",
            "Has memory usage increased recently?",
            "Are there memory leaks in tests or application?",
            "Is the pipeline step size (1x, 2x, 4x) appropriate?",
            "Are too many tests running in parallel?",
            "Is JVM heap size configured correctly?"
        ],
        "investigation_paths": [
            {
                "path": "Analyze memory usage",
                "actions": [
                    "Review logs for OutOfMemoryError details",
                    "Check which phase runs out of memory (compile, test, etc.)",
                    "Compare memory usage with previous builds",
                    "Identify memory-intensive tests or operations"
                ]
            },
            {
                "path": "Optimize memory usage",
                "actions": [
                    "Reduce parallel test execution",
                    "Increase JVM heap size (-Xmx parameter)",
                    "Check for memory leaks in tests",
                    "Use memory profiling tools locally"
                ]
            },
            {
                "path": "Increase pipeline memory",
                "actions": [
                    "Edit bitbucket-pipelines.yml",
                    "Change size from 1x to 2x (or 2x to 4x)",
                    "Document why more memory is needed",
                    "Monitor if increase resolves issue"
                ]
            }
        ],
        "common_causes": [
            "Pipeline step size too small for workload",
            "Memory leak in tests or application code",
            "Too many tests running in parallel",
            "Large datasets loaded into memory",
            "JVM heap size not configured (using default)",
            "Gradle daemon consuming too much memory",
            "Spring Boot test context not released between tests"
        ],
        "prevention_tips": [
            "Start with 2x pipeline size for Java/Quarkus projects",
            "Configure JVM heap size explicitly (-Xmx2g)",
            "Limit parallel test execution (4-8 threads max)",
            "Use memory profiling to detect leaks early",
            "Clear test context between tests (@DirtiesContext)",
            "Monitor memory usage trends over time"
        ],
        "related_docs": [
            "https://support.atlassian.com/bitbucket-cloud/docs/configure-your-pipeline/",
            "https://docs.oracle.com/en/java/javase/11/troubleshoot/troubleshoot-memory-leaks.html"
        ]
    },
    "network_error": {
        "diagnostic_questions": [
            "Is the external service currently down or degraded?",
            "Are there network connectivity issues?",
            "Is a VPN or proxy required to access the service?",
            "Has the service endpoint changed?",
            "Are firewall rules blocking the connection?",
            "Is DNS resolution working correctly?"
        ],
        "investigation_paths": [
            {
                "path": "Check external service status",
                "actions": [
                    "Check status page for Maven Central, npm registry, etc.",
                    "Verify service endpoint is correct",
                    "Test connectivity with curl or ping",
                    "Check if service is temporarily down"
                ]
            },
            {
                "path": "Review network configuration",
                "actions": [
                    "Verify proxy settings if behind corporate firewall",
                    "Check firewall rules for outbound connections",
                    "Confirm DNS resolution is working",
                    "Test connection from same network as pipeline"
                ]
            },
            {
                "path": "Retry or add fallback",
                "actions": [
                    "Simply retry the build (transient failures are common)",
                    "Configure retry logic in build script",
                    "Add fallback to mirror repository",
                    "Increase network timeout values"
                ]
            }
        ],
        "common_causes": [
            "Transient network connectivity issues",
            "External service temporarily down or rate-limited",
            "DNS resolution failure",
            "Firewall blocking outbound connections",
            "Incorrect service endpoint URL",
            "VPN or proxy configuration required but not set",
            "Network timeout set too low"
        ],
        "prevention_tips": [
            "Configure retry logic for network operations",
            "Use repository mirrors for high availability",
            "Set reasonable network timeout values (30-60 seconds)",
            "Monitor external service status pages",
            "Document network dependencies and endpoints",
            "Test connectivity during pipeline setup"
        ],
        "related_docs": [
            "https://status.maven.org/",
            "https://status.npmjs.org/",
            "https://www.cloudflarestatus.com/"
        ]
    },
    "permission_denied": {
        "diagnostic_questions": [
            "Have the credentials changed or expired?",
            "Does the service account have necessary permissions?",
            "Are access tokens still valid?",
            "Is two-factor authentication blocking access?",
            "Are SSH keys properly configured?",
            "Has the repository access policy changed?"
        ],
        "investigation_paths": [
            {
                "path": "Verify credentials",
                "actions": [
                    "Check repository/deployment variables for credentials",
                    "Verify access tokens have not expired",
                    "Test credentials manually outside pipeline",
                    "Confirm username/password are correct"
                ]
            },
            {
                "path": "Check permissions",
                "actions": [
                    "Verify service account has read/write permissions",
                    "Check artifact repository permissions",
                    "Confirm deployment target permissions",
                    "Review recent permission changes"
                ]
            },
            {
                "path": "Update credentials",
                "actions": [
                    "Generate new access token if expired",
                    "Update repository variables with new credentials",
                    "Rotate SSH keys if compromised",
                    "Document credential rotation procedure"
                ]
            }
        ],
        "common_causes": [
            "Access tokens expired (common after 90 days)",
            "Service account permissions revoked",
            "SSH keys not configured or expired",
            "Wrong credentials in repository variables",
            "Two-factor authentication blocking API access",
            "Repository access policy changed",
            "IP address whitelist not including pipeline IPs"
        ],
        "prevention_tips": [
            "Set calendar reminders for credential expiration",
            "Use service accounts instead of personal credentials",
            "Document credential rotation procedures",
            "Monitor for authentication failures",
            "Use secret management tools (Vault, AWS Secrets Manager)",
            "Implement credential expiration alerts"
        ],
        "related_docs": [
            "https://support.atlassian.com/bitbucket-cloud/docs/variables-and-secrets/",
            "https://support.atlassian.com/bitbucket-cloud/docs/use-ssh-keys-in-bitbucket-pipelines/"
        ]
    },
    "docker_error": {
        "diagnostic_questions": [
            "Is the Docker image name and tag correct?",
            "Does the image exist in the registry?",
            "Are Docker Hub credentials configured for private images?",
            "Is there sufficient disk space?",
            "Is the Dockerfile syntax correct?",
            "Are base images accessible?"
        ],
        "investigation_paths": [
            {
                "path": "Verify Docker image",
                "actions": [
                    "Check image name and tag are correct",
                    "Verify image exists in Docker Hub or private registry",
                    "Test pulling image manually: docker pull <image>",
                    "Check if image was recently deleted or renamed"
                ]
            },
            {
                "path": "Check Docker Hub credentials",
                "actions": [
                    "Verify credentials for private images are set",
                    "Test Docker Hub login manually",
                    "Confirm rate limits are not exceeded",
                    "Check if account is active"
                ]
            },
            {
                "path": "Review Dockerfile",
                "actions": [
                    "Check Dockerfile syntax is correct",
                    "Verify base image exists (FROM line)",
                    "Test building image locally",
                    "Check for sufficient disk space"
                ]
            }
        ],
        "common_causes": [
            "Docker image name or tag incorrect",
            "Private image but no credentials configured",
            "Docker Hub rate limit exceeded (anonymous pulls)",
            "Base image not found or deleted",
            "Insufficient disk space for image layers",
            "Dockerfile syntax error",
            "Network issue pulling image"
        ],
        "prevention_tips": [
            "Pin image versions instead of using :latest",
            "Use authenticated Docker Hub account to avoid rate limits",
            "Cache Docker layers to speed up builds",
            "Monitor disk space usage",
            "Test Dockerfile builds locally before pushing",
            "Use private registry for critical images"
        ],
        "related_docs": [
            "https://docs.docker.com/engine/reference/builder/",
            "https://support.atlassian.com/bitbucket-cloud/docs/use-docker-images-as-build-environments/",
            "https://www.docker.com/increase-rate-limits"
        ]
    },
    "unknown": {
        "diagnostic_questions": [
            "What changed since the last successful build?",
            "Are there any error messages in the logs?",
            "Is this a new type of failure not seen before?",
            "Were there recent infrastructure changes?",
            "Is the failure reproducible locally?"
        ],
        "investigation_paths": [
            {
                "path": "Manual log review",
                "actions": [
                    "Read full build logs carefully",
                    "Look for error messages or stack traces",
                    "Check for warnings that might be clues",
                    "Compare with successful build logs"
                ]
            },
            {
                "path": "Check recent changes",
                "actions": [
                    "Review commits since last successful build",
                    "Check for infrastructure or configuration changes",
                    "Look for changes to pipeline configuration",
                    "Verify external dependencies are stable"
                ]
            },
            {
                "path": "Reproduce locally",
                "actions": [
                    "Try to reproduce failure on local machine",
                    "Run same commands as pipeline",
                    "Check if failure is environment-specific",
                    "Test with same tool versions as pipeline"
                ]
            }
        ],
        "common_causes": [
            "New type of failure not yet categorized",
            "Infrastructure issue (Bitbucket Pipelines outage)",
            "Complex interaction of multiple factors",
            "Rare edge case or timing issue",
            "External service issue not covered by patterns"
        ],
        "prevention_tips": [
            "Document new failure types for future reference",
            "Add error patterns to detection system",
            "Monitor Bitbucket Pipelines status page",
            "Keep detailed logs of failures for analysis",
            "Share knowledge with team about unusual failures"
        ],
        "related_docs": [
            "https://status.bitbucket.org/",
            "https://community.atlassian.com/t5/Bitbucket-Pipelines/ct-p/bitbucket-pipelines"
        ]
    }
}


def get_instructions(error_type: str) -> Dict:
    """
    Get contextual instructions for error type.

    Args:
        error_type: Error type key (e.g., "test_failure")

    Returns:
        Instruction template dict with questions, paths, causes, tips

    Example:
        >>> instructions = get_instructions("test_failure")
        >>> len(instructions["diagnostic_questions"])
        7
    """
    return INSTRUCTION_TEMPLATES.get(error_type, INSTRUCTION_TEMPLATES["unknown"])


def list_all_instruction_types() -> List[str]:
    """
    Get list of all instruction template types.

    Returns:
        List of error types with instructions

    Example:
        >>> types = list_all_instruction_types()
        >>> "test_failure" in types
        True
    """
    return list(INSTRUCTION_TEMPLATES.keys())


def get_diagnostic_questions(error_type: str) -> List[str]:
    """
    Get diagnostic questions for error type.

    Args:
        error_type: Error type key

    Returns:
        List of diagnostic questions

    Example:
        >>> questions = get_diagnostic_questions("timeout")
        >>> "How long does this step normally take?" in questions
        True
    """
    instructions = get_instructions(error_type)
    return instructions.get("diagnostic_questions", [])


def get_investigation_paths(error_type: str) -> List[Dict]:
    """
    Get investigation paths for error type.

    Args:
        error_type: Error type key

    Returns:
        List of investigation path dicts

    Example:
        >>> paths = get_investigation_paths("dependency_conflict")
        >>> len(paths)
        3
    """
    instructions = get_instructions(error_type)
    return instructions.get("investigation_paths", [])


def get_prevention_tips(error_type: str) -> List[str]:
    """
    Get prevention tips for error type.

    Args:
        error_type: Error type key

    Returns:
        List of prevention tips

    Example:
        >>> tips = get_prevention_tips("memory_error")
        >>> any("JVM" in tip for tip in tips)
        True
    """
    instructions = get_instructions(error_type)
    return instructions.get("prevention_tips", [])
