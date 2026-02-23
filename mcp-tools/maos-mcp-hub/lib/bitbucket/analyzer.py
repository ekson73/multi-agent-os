"""
Pipeline analysis and failure diagnosis

This module provides intelligent analysis of pipeline failures,
pattern detection, and automated diagnosis with actionable suggestions.
"""

import asyncio
import json
import re
from collections import Counter
from typing import Optional
from .client import BitbucketPipelineClient


def extract_json_from_response(content: str) -> dict:
    """
    Extract JSON from markdown-wrapped or plain responses

    AI providers sometimes wrap JSON in markdown code blocks like:
    ```json
    {"key": "value"}
    ```

    This function handles:
    - Plain JSON (tries first)
    - Markdown JSON code blocks (```json...```)
    - Generic code blocks (```...```)

    Args:
        content: Raw response content from AI API

    Returns:
        dict: Parsed JSON object

    Raises:
        ValueError: If no valid JSON found in response
    """
    # Try plain JSON first (most common)
    try:
        return json.loads(content)
    except json.JSONDecodeError:
        pass

    # Try markdown JSON code block: ```json\n{...}\n```
    match = re.search(r'```json\s*\n(.*?)\n```', content, re.DOTALL)
    if match:
        try:
            return json.loads(match.group(1))
        except json.JSONDecodeError:
            pass

    # Try generic code block: ```\n{...}\n```
    match = re.search(r'```\s*\n(.*?)\n```', content, re.DOTALL)
    if match:
        try:
            return json.loads(match.group(1))
        except json.JSONDecodeError:
            pass

    # Last resort: try to find any JSON object in the text
    match = re.search(r'\{.*\}', content, re.DOTALL)
    if match:
        try:
            return json.loads(match.group(0))
        except json.JSONDecodeError:
            pass

    raise ValueError(f"No valid JSON found in response (length: {len(content)})")


class PipelineAnalyzer:
    """
    Analyzer for pipeline failures and patterns

    Provides methods to:
    - Analyze failure patterns across multiple builds
    - Diagnose specific build failures with suggestions
    - Compare builds step-by-step
    """

    # Knowledge base for failure diagnosis
    STEP_DIAGNOSIS_MAP = {
        "unit tests": {
            "possible_causes": [
                "Java version mismatch between pipeline and project",
                "Maven dependency resolution issues",
                "Test configuration errors (skipTests, maven.test.skip)",
                "Flaky tests or race conditions",
            ],
            "suggestions": [
                "Check Java version in pipeline vs pom.xml",
                "Verify maven.test.skip and skipTests settings",
                "Review test logs for specific failures",
                "Run tests locally to reproduce",
            ],
        },
        "maven build": {
            "possible_causes": [
                "Compilation errors in source code",
                "Dependency resolution failures",
                "Insufficient memory or resources",
                "Plugin configuration errors",
            ],
            "suggestions": [
                "Check Maven dependencies and versions",
                "Verify Java version compatibility",
                "Review pom.xml configuration",
                "Check for missing or conflicting dependencies",
            ],
        },
        "security": {
            "possible_causes": [
                "Known vulnerabilities in dependencies (CVE)",
                "Security scanner configuration issues",
                "Threshold violations",
                "False positives from scanner",
            ],
            "suggestions": [
                "Review dependency-check report for CVEs",
                "Update vulnerable dependencies",
                "Review security-scan.sh configuration",
                "Consider suppressing false positives",
            ],
        },
        "deploy": {
            "possible_causes": [
                "Missing or invalid credentials",
                "Network connectivity issues",
                "Deployment target unavailable",
                "Configuration errors in deployment script",
            ],
            "suggestions": [
                "Verify environment variables (AWS_*, FLY_*, etc.)",
                "Check deployment target health",
                "Review deployment logs for authentication errors",
                "Validate deployment configuration",
            ],
        },
        "test": {
            "possible_causes": [
                "Test failures or assertion errors",
                "Test environment issues",
                "Database or external service unavailable",
                "Test data problems",
            ],
            "suggestions": [
                "Review specific test failures in logs",
                "Check test environment configuration",
                "Verify external service dependencies",
                "Validate test data setup",
            ],
        },
    }

    def __init__(self, client: BitbucketPipelineClient):
        """
        Initialize analyzer with Bitbucket client

        Args:
            client: BitbucketPipelineClient instance for API calls
        """
        self.client = client

    async def analyze_failure_patterns(self, count: int = 10) -> dict:
        """
        Analyze failure patterns across recent failed builds

        Args:
            count: Number of failed builds to analyze (max: 50)

        Returns:
            dict: {
                "failed_builds": [build_numbers],
                "failure_patterns": [{"step": name, "count": N}],
                "most_common_failures": [top 5 step names]
            }
        """
        # Get recent pipelines (fetch more to find N failures)
        pipelines_data = await self.client.get_pipelines(pagelen=min(50, count * 5))

        # Filter failed builds
        failed_builds = [
            p
            for p in pipelines_data.get("values", [])
            if p.get("state", {}).get("result", {}).get("name") == "FAILED"
        ][:count]

        if not failed_builds:
            return {
                "failed_builds": [],
                "failure_patterns": [],
                "most_common_failures": [],
                "message": "No failed builds found in recent history",
            }

        # Collect failed steps from each build (parallel)
        tasks = [
            self._get_failed_steps(build["build_number"]) for build in failed_builds
        ]
        all_failed_steps = await asyncio.gather(*tasks)

        # Flatten list and count occurrences
        failure_list = [step for steps in all_failed_steps for step in steps]
        counter = Counter(failure_list)

        return {
            "failed_builds": [b["build_number"] for b in failed_builds],
            "failure_patterns": [
                {"step": step, "count": count} for step, count in counter.most_common()
            ],
            "most_common_failures": [step for step, _ in counter.most_common(5)],
        }

    async def _get_failed_steps(self, build_number: int) -> list[str]:
        """
        Helper: Get names of failed steps for a build

        Args:
            build_number: Build to analyze

        Returns:
            list[str]: Names of failed steps
        """
        try:
            steps_data = await self.client.get_pipeline_steps(build_number)
            return [
                step["name"]
                for step in steps_data.get("values", [])
                if step.get("state", {}).get("result", {}).get("name") == "FAILED"
            ]
        except Exception:
            return []

    async def diagnose_build(self, build_number: int) -> dict:
        """
        Automatically diagnose a failed build with actionable suggestions

        Args:
            build_number: Build to diagnose

        Returns:
            dict: {
                "build_info": {...},
                "status": "FAILED" | "NOT_FAILED" | "IN_PROGRESS",
                "failed_steps": [{name, possible_causes, suggestions}],
                "last_successful_build": build_number | None,
                "comparison_available": bool
            }
        """
        # Get build details
        try:
            build = await self.client.get_pipeline(build_number)
        except Exception as e:
            return {
                "error": f"Failed to fetch build {build_number}",
                "details": str(e),
            }

        result = build.get("state", {}).get("result", {}).get("name", "IN_PROGRESS")

        if result != "FAILED":
            return {
                "build_info": {
                    "build_number": build_number,
                    "result": result,
                    "branch": build.get("target", {}).get("ref_name"),
                    "commit": build.get("target", {}).get("commit", {}).get("hash", "")[:8],
                },
                "status": result,
                "message": f"Build did not fail (status: {result})",
            }

        # Get failed steps
        steps_data = await self.client.get_pipeline_steps(build_number)
        failed_steps = [
            step
            for step in steps_data.get("values", [])
            if step.get("state", {}).get("result", {}).get("name") == "FAILED"
        ]

        # Diagnose each failed step
        diagnosed_steps = []
        for step in failed_steps:
            step_name = step["name"]
            diagnosis = {
                "name": step_name,
                "state": step["state"]["name"],
                "result": step["state"].get("result", {}).get("name", "N/A"),
            }

            # Match against knowledge base
            step_lower = step_name.lower()
            matched = False

            for pattern, info in self.STEP_DIAGNOSIS_MAP.items():
                if pattern in step_lower:
                    diagnosis["possible_causes"] = info["possible_causes"]
                    diagnosis["suggestions"] = info["suggestions"]
                    matched = True
                    break

            if not matched:
                diagnosis["suggestions"] = [
                    "Check step logs for specific error messages",
                    "Compare with previous successful builds",
                    "Verify step configuration in bitbucket-pipelines.yml",
                ]

            diagnosed_steps.append(diagnosis)

        # Find last successful build (parallel)
        last_success_task = self._find_last_successful_build()
        last_success = await last_success_task

        return {
            "build_info": {
                "build_number": build_number,
                "result": result,
                "branch": build.get("target", {}).get("ref_name"),
                "commit": build.get("target", {}).get("commit", {}).get("hash", "")[:8],
                "created_on": build.get("created_on"),
            },
            "status": "FAILED",
            "failed_steps": diagnosed_steps,
            "last_successful_build": last_success,
            "comparison_available": last_success is not None,
        }

    async def _find_last_successful_build(self) -> Optional[int]:
        """
        Helper: Find the most recent successful build

        Returns:
            int | None: Build number of last successful build, or None
        """
        try:
            pipelines = await self.client.get_pipelines(pagelen=50)
            for build in pipelines.get("values", []):
                if build.get("state", {}).get("result", {}).get("name") == "SUCCESSFUL":
                    return build["build_number"]
            return None
        except Exception:
            return None

    async def compare_builds(self, build1: int, build2: int) -> dict:
        """
        Compare two builds step-by-step

        Args:
            build1: First build number
            build2: Second build number

        Returns:
            dict: {
                "build1": {build_number, result, steps},
                "build2": {build_number, result, steps},
                "differences": [{step, result1, result2, changed}]
            }
        """
        # Fetch all data in parallel
        try:
            build1_data, build2_data, steps1_data, steps2_data = await asyncio.gather(
                self.client.get_pipeline(build1),
                self.client.get_pipeline(build2),
                self.client.get_pipeline_steps(build1),
                self.client.get_pipeline_steps(build2),
            )
        except Exception as e:
            return {"error": f"Failed to fetch build data: {str(e)}"}

        # Create step result maps
        steps1_map = {
            step["name"]: step.get("state", {}).get("result", {}).get("name", "N/A")
            for step in steps1_data.get("values", [])
        }
        steps2_map = {
            step["name"]: step.get("state", {}).get("result", {}).get("name", "N/A")
            for step in steps2_data.get("values", [])
        }

        # Find all unique step names
        all_steps = sorted(set(steps1_map.keys()) | set(steps2_map.keys()))

        # Compare step by step
        differences = []
        for step_name in all_steps:
            result1 = steps1_map.get(step_name, "ABSENT")
            result2 = steps2_map.get(step_name, "ABSENT")
            differences.append({
                "step": step_name,
                "result1": result1,
                "result2": result2,
                "changed": result1 != result2,
            })

        return {
            "build1": {
                "build_number": build1,
                "result": build1_data.get("state", {}).get("result", {}).get("name", "N/A"),
                "branch": build1_data.get("target", {}).get("ref_name"),
                "commit": build1_data.get("target", {}).get("commit", {}).get("hash", "")[:8],
                "steps": steps1_map,
            },
            "build2": {
                "build_number": build2,
                "result": build2_data.get("state", {}).get("result", {}).get("name", "N/A"),
                "branch": build2_data.get("target", {}).get("ref_name"),
                "commit": build2_data.get("target", {}).get("commit", {}).get("hash", "")[:8],
                "steps": steps2_map,
            },
            "differences": differences,
            "summary": {
                "total_steps": len(all_steps),
                "changed_steps": sum(1 for d in differences if d["changed"]),
                "same_steps": sum(1 for d in differences if not d["changed"]),
            },
        }

    async def diagnose_pipeline_failure(
        self, build_number: int, step_name: Optional[str] = None
    ) -> dict:
        """
        Hybrid local analysis: Pattern Matching + Contextual Instructions

        Phase 1: Structural analysis (patterns)
        Phase 2: Contextual guidance (instructions)
        Phase 3: Combine results

        Args:
            build_number: Pipeline build number
            step_name: Optional step name (auto-detects failed step if not provided)

        Returns:
            {
                "method": "hybrid_local",
                "build_number": int,
                "step_name": str,
                "diagnosis": {
                    "error_type": str,
                    "severity": str,
                    "category": str,
                    "confidence": float,
                    "matched_patterns": [...],
                    "root_cause_hypothesis": str
                },
                "immediate_actions": [...],
                "diagnostic_questions": [...],
                "investigation_paths": [...],
                "common_causes": [...],
                "prevention_tips": [...],
                "auto_fixable": bool,
                "safety_level": str,
                "estimated_fix_time": str
            }

        Example:
            >>> analyzer = PipelineAnalyzer(client)
            >>> result = await analyzer.diagnose_pipeline_failure(42)
            >>> result["diagnosis"]["error_type"]
            'test_failure'
        """
        from .patterns import match_error_patterns
        from .instructions import get_instructions
        from datetime import datetime

        # Get build and step info
        build = await self.client.get_pipeline(build_number)

        if not step_name:
            # Find failed step
            steps_data = await self.client.get_pipeline_steps(build_number)
            for step in steps_data.get("values", []):
                if step.get("state", {}).get("result", {}).get("name") == "FAILED":
                    step_name = step.get("name")
                    break

        if not step_name:
            return {
                "success": False,
                "error": "No failed step found",
                "suggestion": "Build may still be running or did not fail",
            }

        # Get logs
        try:
            logs_response = await self.client.get_step_logs(build_number, step_name)
            logs = logs_response.get("logs", "")
        except Exception as e:
            return {
                "success": False,
                "error": f"Failed to fetch logs: {str(e)}",
                "build_number": build_number,
                "step_name": step_name,
            }

        # PHASE 1: Pattern Matching
        pattern_result = match_error_patterns(logs)

        if not pattern_result["matched"]:
            return {
                "method": "hybrid_local",
                "build_number": build_number,
                "step_name": step_name,
                "diagnosis": {
                    "error_type": "unknown",
                    "severity": "unknown",
                    "category": "unknown",
                    "confidence": 0.0,
                    "matched_patterns": [],
                    "root_cause_hypothesis": "No known error patterns detected in logs",
                },
                "immediate_actions": [
                    "Manually review full build logs",
                    "Check for infrastructure issues",
                    "Contact DevOps if issue persists",
                ],
                "diagnostic_questions": [
                    "Is this a new type of failure not seen before?",
                    "Were there recent infrastructure changes?",
                ],
                "investigation_paths": [],
                "common_causes": [],
                "prevention_tips": [],
                "auto_fixable": False,
                "safety_level": "N/A",
                "estimated_fix_time": "Unknown - manual investigation required",
            }

        # PHASE 2: Enrich with Instructions
        error_type = pattern_result["error_type"]
        instructions = get_instructions(error_type)

        # PHASE 3: Combine Results
        solutions = (
            pattern_result["solutions"][0] if pattern_result["solutions"] else {}
        )

        return {
            "method": "hybrid_local",
            "build_number": build_number,
            "step_name": step_name,
            "branch": build.get("target", {}).get("ref_name", "unknown"),
            "commit": build.get("target", {}).get("commit", {}).get("hash", "unknown")[
                :7
            ],
            "diagnosis": {
                "error_type": error_type,
                "severity": pattern_result["severity"],
                "category": pattern_result["category"],
                "confidence": pattern_result["confidence"],
                "matched_patterns": pattern_result["matches"],
                "root_cause_hypothesis": f"Build failed due to {error_type.replace('_', ' ')}",
            },
            "immediate_actions": solutions.get("steps", []),
            "diagnostic_questions": instructions.get("diagnostic_questions", []),
            "investigation_paths": instructions.get("investigation_paths", []),
            "common_causes": instructions.get("common_causes", []),
            "prevention_tips": instructions.get("prevention_tips", []),
            "auto_fixable": solutions.get("auto_fixable", False),
            "safety_level": solutions.get("safety", "N/A"),
            "estimated_fix_time": self._estimate_fix_time(
                error_type, solutions.get("auto_fixable", False)
            ),
            "context": {
                "total_log_lines": len(logs.split("\n")),
                "analysis_timestamp": datetime.utcnow().isoformat() + "Z",
            },
        }

    def _estimate_fix_time(self, error_type: str, auto_fixable: bool) -> str:
        """Estimate time to fix based on error type"""
        if auto_fixable:
            return "5-10 minutes (auto-fixable)"

        time_estimates = {
            "test_failure": "15-30 minutes",
            "dependency_conflict": "10-20 minutes",
            "compilation_error": "20-60 minutes",
            "timeout": "5-15 minutes",
            "memory_error": "10-20 minutes",
            "network_error": "5-10 minutes (retry)",
            "permission_denied": "10-20 minutes",
            "docker_error": "15-30 minutes",
        }

        return time_estimates.get(error_type, "30-60 minutes")

    async def diagnose_with_ai(
        self, build_number: int, step_name: Optional[str] = None, use_api: bool = True
    ) -> dict:
        """
        Enhanced diagnosis with FREE AI APIs (round-robin fallback)

        Flow:
        1. Run local hybrid analysis (Phase 1)
        2. IF confidence < 0.8 AND use_api=True:
           - Build enriched prompt WITH local context
           - Try APIs in round-robin order (DeepSeek → Gemini → Mistral)
           - Merge AI validation with local analysis
        3. Return combined result

        Args:
            build_number: Pipeline build number
            step_name: Optional step name (auto-detects if not provided)
            use_api: Enable AI enhancement (requires API keys)

        Returns:
            {
                "method": "hybrid_ai_enhanced" | "hybrid_local",
                ...diagnosis fields from local analysis...,
                "additional_insights": [...],  # From AI
                "ai_enhancement": {
                    "attempted": true,
                    "success": true/false,
                    "provider": "deepseek",
                    "tokens_used": 234,
                    "confidence_adjustment": +0.15
                }
            }

        Example:
            >>> analyzer = PipelineAnalyzer(client)
            >>> result = await analyzer.diagnose_with_ai(42, use_api=True)
            >>> result["method"]
            'hybrid_ai_enhanced'
            >>> result["ai_enhancement"]["success"]
            True
        """
        import json
        from .api_providers import APIProviderManager, build_enriched_prompt

        # STEP 1: Local hybrid analysis
        local_result = await self.diagnose_pipeline_failure(build_number, step_name)

        # Handle error cases from local analysis
        if not local_result.get("success", True) and "error" in local_result:
            local_result["ai_enhancement"] = {
                "attempted": False,
                "reason": "Local analysis failed",
            }
            return local_result

        # STEP 2: Check if AI enhancement needed
        confidence = local_result["diagnosis"]["confidence"]

        if confidence >= 0.8:
            # Local analysis is confident enough
            local_result["ai_enhancement"] = {
                "attempted": False,
                "reason": f"Local confidence sufficient ({confidence:.0%})",
            }
            return local_result

        if not use_api:
            # AI disabled by user
            local_result["ai_enhancement"] = {
                "attempted": False,
                "reason": "AI enhancement disabled (use_api=False)",
            }
            return local_result

        # STEP 3: Get logs for AI context
        try:
            logs_response = await self.client.get_step_logs(
                build_number, local_result["step_name"]
            )
            logs = logs_response.get("logs", "")
        except Exception as e:
            local_result["ai_enhancement"] = {
                "attempted": False,
                "reason": f"Failed to fetch logs: {str(e)}",
            }
            return local_result

        # STEP 4: Build enriched prompt with local context
        error_log_truncated = "\n".join(logs.split("\n")[-100:])  # Last 100 lines

        prompt = build_enriched_prompt(
            build_number=build_number,
            step_name=local_result["step_name"],
            branch=local_result.get("branch", "unknown"),
            error_log=error_log_truncated,
            local_analysis=local_result,
        )

        # STEP 5: Try AI APIs with round-robin fallback
        api_manager = APIProviderManager()

        try:
            api_result = await api_manager.diagnose_with_fallback(
                prompt, max_attempts=3
            )
        except Exception as e:
            local_result["ai_enhancement"] = {
                "attempted": True,
                "success": False,
                "reason": f"API call failed: {str(e)}",
            }
            return local_result

        if not api_result.get("success"):
            # All APIs failed
            local_result["ai_enhancement"] = {
                "attempted": True,
                "success": False,
                "reason": api_result.get(
                    "error", "All API providers failed or rate limited"
                ),
                "attempts": api_result.get("attempts", 0),
            }
            return local_result

        # STEP 6: Parse AI response (JSON with markdown extraction)
        try:
            ai_analysis = extract_json_from_response(api_result["content"])
        except (json.JSONDecodeError, ValueError) as e:
            # AI didn't return valid JSON, even after markdown extraction
            local_result["ai_enhancement"] = {
                "attempted": True,
                "success": False,
                "reason": f"AI response parsing failed: {str(e)}",
                "raw_response": api_result["content"][:200],
            }
            return local_result

        # STEP 7: Merge local + AI analysis
        adjusted_confidence = confidence + ai_analysis.get("confidence_adjustment", 0)
        adjusted_confidence = max(0.0, min(1.0, adjusted_confidence))

        # Build enhanced result
        enhanced_result = local_result.copy()
        enhanced_result["method"] = "hybrid_ai_enhanced"

        # Update diagnosis with AI validation
        enhanced_result["diagnosis"]["confidence"] = adjusted_confidence
        enhanced_result["diagnosis"]["ai_validation"] = ai_analysis.get(
            "validates_local_analysis", None
        )

        if not ai_analysis.get("validates_local_analysis", True):
            # AI disagreed with local analysis
            enhanced_result["diagnosis"]["validation_notes"] = ai_analysis.get(
                "validation_notes", ""
            )
            if ai_analysis.get("alternative_diagnosis"):
                enhanced_result["diagnosis"]["alternative_error_type"] = ai_analysis[
                    "alternative_diagnosis"
                ]

        # Update root cause if AI provided better explanation
        if ai_analysis.get("root_cause"):
            enhanced_result["diagnosis"]["ai_root_cause"] = ai_analysis["root_cause"]

        # Add AI insights
        enhanced_result["additional_insights"] = ai_analysis.get(
            "additional_insights", []
        )
        enhanced_result["recommended_priority"] = ai_analysis.get(
            "recommended_priority", "medium"
        )

        # Add AI enhancement metadata
        enhanced_result["ai_enhancement"] = {
            "attempted": True,
            "success": True,
            "provider": api_result["provider"],
            "tokens_used": api_result.get("tokens_used", 0),
            "attempts": api_result.get("attempts", 1),
            "confidence_adjustment": ai_analysis.get("confidence_adjustment", 0),
            "validates_local": ai_analysis.get("validates_local_analysis", True),
        }

        return enhanced_result
