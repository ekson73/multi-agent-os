"""
Pipeline health monitoring and alerting

This module monitors overall pipeline health, calculates metrics,
and detects anomalies and issues that require attention.
"""

from datetime import datetime, timedelta, timezone
from collections import Counter
from .client import BitbucketPipelineClient
from .models import PipelineHealth


class HealthMonitor:
    """
    Monitor pipeline health and detect alerts

    Provides methods to:
    - Calculate overall pipeline health metrics
    - Detect various types of alerts (failures, slow builds, etc.)
    - Generate actionable recommendations
    """

    def __init__(self, client: BitbucketPipelineClient):
        """
        Initialize health monitor with Bitbucket client

        Args:
            client: BitbucketPipelineClient instance for API calls
        """
        self.client = client

    async def check_health(self, sample_size: int = 20) -> PipelineHealth:
        """
        Check overall pipeline health based on recent builds

        Args:
            sample_size: Number of recent builds to analyze (default: 20)

        Returns:
            PipelineHealth: Health metrics and status
        """
        # Fetch recent pipelines
        pipelines_data = await self.client.get_pipelines(pagelen=sample_size)
        builds = pipelines_data.get("values", [])

        if not builds:
            # No builds available
            return PipelineHealth(
                status="CRITICAL",
                success_rate=0.0,
                total_builds=0,
                successful_builds=0,
                failed_builds=0,
                in_progress_builds=0,
                recent_failures=[],
                top_failing_branches=[],
            )

        # Count build states
        total = len(builds)
        successful = sum(
            1
            for b in builds
            if b.get("state", {}).get("result", {}).get("name") == "SUCCESSFUL"
        )
        failed = sum(
            1
            for b in builds
            if b.get("state", {}).get("result", {}).get("name") == "FAILED"
        )
        in_progress = sum(
            1 for b in builds if b.get("state", {}).get("name") == "IN_PROGRESS"
        )

        # Calculate success rate (exclude in-progress)
        completed = successful + failed
        success_rate = (successful / completed * 100) if completed > 0 else 0.0

        # Determine overall status
        if success_rate >= 90:
            status = "EXCELLENT"
        elif success_rate >= 75:
            status = "GOOD"
        elif success_rate >= 50:
            status = "NEEDS_ATTENTION"
        else:
            status = "CRITICAL"

        # Calculate average duration (successful builds only)
        durations = [
            b.get("duration_in_seconds", 0)
            for b in builds
            if b.get("state", {}).get("result", {}).get("name") == "SUCCESSFUL"
            and b.get("duration_in_seconds")
        ]
        avg_duration = (sum(durations) / len(durations)) if durations else None

        # Recent failures (last 5 failed builds)
        recent_failures = [
            b["build_number"]
            for b in builds[:10]
            if b.get("state", {}).get("result", {}).get("name") == "FAILED"
        ][:5]

        # Top failing branches
        failed_branches = [
            b.get("target", {}).get("ref_name", "unknown")
            for b in builds
            if b.get("state", {}).get("result", {}).get("name") == "FAILED"
        ]
        branch_counter = Counter(failed_branches)
        top_branches = [
            {"branch": branch, "failures": count}
            for branch, count in branch_counter.most_common(3)
        ]

        return PipelineHealth(
            status=status,
            success_rate=round(success_rate, 1),
            total_builds=total,
            successful_builds=successful,
            failed_builds=failed,
            in_progress_builds=in_progress,
            avg_duration_seconds=(round(avg_duration, 1) if avg_duration else None),
            recent_failures=recent_failures,
            top_failing_branches=top_branches,
        )

    async def check_alerts(self) -> dict:
        """
        Check for pipeline alerts and anomalies

        Returns:
            dict: {
                "alerts_found": N,
                "consecutive_failures": N,
                "long_running_builds": [build_numbers],
                "high_failure_rate": bool,
                "slow_builds": [build_numbers],
                "alerts": [Alert objects],
                "recommendations": [actionable suggestions]
            }
        """
        # Fetch recent pipelines
        pipelines_data = await self.client.get_pipelines(pagelen=10)
        builds = pipelines_data.get("values", [])

        if not builds:
            return {
                "alerts_found": 0,
                "consecutive_failures": 0,
                "long_running_builds": [],
                "high_failure_rate": False,
                "slow_builds": [],
                "alerts": [],
                "recommendations": ["No builds available to analyze"],
            }

        alerts = []

        # Alert 1: Consecutive failures
        consecutive = 0
        for build in builds:
            if build.get("state", {}).get("result", {}).get("name") == "FAILED":
                consecutive += 1
            else:
                break

        if consecutive >= 3:
            alerts.append({
                "type": "consecutive_failures",
                "severity": "CRITICAL",
                "message": f"{consecutive} consecutive failures detected",
                "affected_builds": [
                    b["build_number"] for b in builds[:consecutive]
                ],
            })
        elif consecutive >= 2:
            alerts.append({
                "type": "consecutive_failures",
                "severity": "WARNING",
                "message": f"{consecutive} consecutive failures",
                "affected_builds": [
                    b["build_number"] for b in builds[:consecutive]
                ],
            })

        # Alert 2: Long-running builds (>2 hours)
        two_hours_ago = datetime.now(timezone.utc) - timedelta(hours=2)
        long_running = []

        for build in builds:
            if build.get("state", {}).get("name") == "IN_PROGRESS":
                created_str = build.get("created_on", "")
                try:
                    # Parse ISO8601 timestamp
                    created = datetime.fromisoformat(
                        created_str.replace("Z", "+00:00")
                    )
                    if created < two_hours_ago:
                        long_running.append(build["build_number"])
                except (ValueError, TypeError):
                    continue

        if long_running:
            alerts.append({
                "type": "long_running",
                "severity": "WARNING",
                "message": f"Builds running >2h: {long_running}",
                "affected_builds": long_running,
            })

        # Alert 3: High failure rate
        completed_builds = [
            b
            for b in builds
            if b.get("state", {}).get("result", {}).get("name")
            in ["SUCCESSFUL", "FAILED"]
        ]

        if completed_builds:
            failed_count = sum(
                1
                for b in completed_builds
                if b.get("state", {}).get("result", {}).get("name") == "FAILED"
            )
            failure_rate = (failed_count / len(completed_builds)) * 100

            if failure_rate >= 50:
                severity = "CRITICAL" if failure_rate >= 70 else "WARNING"
                alerts.append({
                    "type": "high_failure_rate",
                    "severity": severity,
                    "message": f"High failure rate: {failure_rate:.1f}%",
                    "details": {
                        "rate": round(failure_rate, 1),
                        "failed": failed_count,
                        "total": len(completed_builds),
                    },
                })

        # Alert 4: Slow builds (>30 minutes = 1800 seconds)
        slow_builds = [
            b["build_number"]
            for b in builds
            if b.get("duration_in_seconds", 0) > 1800
        ]

        if slow_builds:
            alerts.append({
                "type": "slow_build",
                "severity": "INFO",
                "message": f"Slow builds detected (>30min): {slow_builds}",
                "affected_builds": slow_builds,
            })

        # Generate recommendations
        recommendations = self._generate_recommendations(alerts, consecutive)

        return {
            "alerts_found": len(alerts),
            "consecutive_failures": consecutive,
            "long_running_builds": long_running,
            "high_failure_rate": any(
                a["type"] == "high_failure_rate" for a in alerts
            ),
            "slow_builds": slow_builds,
            "alerts": alerts,
            "recommendations": recommendations,
        }

    def _generate_recommendations(
        self, alerts: list[dict], consecutive_failures: int
    ) -> list[str]:
        """
        Generate actionable recommendations based on alerts

        Args:
            alerts: List of alert dictionaries
            consecutive_failures: Number of consecutive failures

        Returns:
            list[str]: Actionable recommendations
        """
        recommendations = []

        # Priority 1: Consecutive failures
        if consecutive_failures >= 3:
            recommendations.append(
                "🔴 CRITICAL: Investigate consecutive failures immediately"
            )
            recommendations.append(
                "→ Use 'analyze_failures' tool to identify common patterns"
            )
            recommendations.append(
                "→ Use 'auto_diagnose' on affected builds for specific suggestions"
            )

        # Priority 2: High failure rate
        for alert in alerts:
            if alert["type"] == "high_failure_rate":
                recommendations.append(
                    f"⚠️ High failure rate ({alert['details']['rate']}%) detected"
                )
                recommendations.append(
                    "→ Run failure pattern analysis to identify root causes"
                )
                recommendations.append(
                    "→ Check if recent changes introduced regressions"
                )

        # Priority 3: Long-running builds
        for alert in alerts:
            if alert["type"] == "long_running":
                recommendations.append(
                    f"⏰ Check if builds {alert['affected_builds']} are stuck"
                )
                recommendations.append(
                    "→ Consider canceling and re-running if blocked"
                )

        # Priority 4: Slow builds
        for alert in alerts:
            if alert["type"] == "slow_build":
                recommendations.append(
                    "💡 Consider optimizing slow build steps"
                )
                recommendations.append(
                    "→ Review step durations and identify bottlenecks"
                )
                recommendations.append(
                    "→ Consider parallelizing independent steps"
                )

        # Default recommendation if no issues
        if not recommendations:
            recommendations.append(
                "✅ No critical issues detected - pipeline is healthy"
            )
            recommendations.append(
                "→ Continue regular monitoring"
            )

        return recommendations
