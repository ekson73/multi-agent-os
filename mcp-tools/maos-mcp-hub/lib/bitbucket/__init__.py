"""
Bitbucket Pipeline Monitor - MCP Server Package

This package implements a Model Context Protocol (MCP) server for monitoring
and analyzing Bitbucket Cloud pipelines.

Main components:
- client: HTTP client for Bitbucket API
- analyzer: Pipeline analysis and failure diagnosis
- health: Health monitoring and alerting
- models: Pydantic data models
"""

__version__ = "1.0.0"
__author__ = "maos-mcp-hub contributors"
__protocol__ = "MCP 1.0 (JSON-RPC 2.0)"

from .client import BitbucketPipelineClient
from .analyzer import PipelineAnalyzer
from .health import HealthMonitor
from .models import Build, Step, BuildState, PipelineHealth, Alert

__all__ = [
    "BitbucketPipelineClient",
    "PipelineAnalyzer",
    "HealthMonitor",
    "Build",
    "Step",
    "BuildState",
    "PipelineHealth",
    "Alert",
]
