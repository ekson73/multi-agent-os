"""
Pydantic data models for Bitbucket Pipeline Monitor

These models define the structure of data returned by the Bitbucket API
and used throughout the application.
"""

from pydantic import BaseModel, Field
from typing import Optional, Literal
from datetime import datetime


class BuildState(BaseModel):
    """Pipeline build state"""

    name: Literal["PENDING", "IN_PROGRESS", "COMPLETED"]
    result: Optional[Literal["SUCCESSFUL", "FAILED", "STOPPED", "ERROR"]] = None


class Build(BaseModel):
    """Pipeline build information"""

    build_number: int
    state: BuildState
    uuid: str
    repository: dict = Field(default_factory=dict)
    target: dict = Field(default_factory=dict)  # commit, branch info
    creator: dict = Field(default_factory=dict)
    created_on: datetime
    completed_on: Optional[datetime] = None
    duration_in_seconds: Optional[int] = None


class Step(BaseModel):
    """Pipeline step information"""

    uuid: str
    name: str
    state: BuildState
    setup_commands: list[dict] = Field(default_factory=list)
    script_commands: list[dict] = Field(default_factory=list)
    image: dict = Field(default_factory=dict)
    build_seconds_used: Optional[int] = None
    max_time: Optional[int] = None
    created_on: Optional[datetime] = None
    completed_on: Optional[datetime] = None


class PipelineHealth(BaseModel):
    """Overall pipeline health metrics"""

    status: Literal["EXCELLENT", "GOOD", "NEEDS_ATTENTION", "CRITICAL"]
    success_rate: float = Field(ge=0.0, le=100.0)
    total_builds: int
    successful_builds: int
    failed_builds: int
    in_progress_builds: int
    avg_duration_seconds: Optional[float] = None
    recent_failures: list[int] = Field(default_factory=list)
    top_failing_branches: list[dict] = Field(default_factory=list)


class Alert(BaseModel):
    """Pipeline alert information"""

    type: Literal[
        "consecutive_failures", "long_running", "high_failure_rate", "slow_build"
    ]
    severity: Literal["CRITICAL", "WARNING", "INFO"]
    message: str
    affected_builds: list[int] = Field(default_factory=list)
    details: dict = Field(default_factory=dict)
