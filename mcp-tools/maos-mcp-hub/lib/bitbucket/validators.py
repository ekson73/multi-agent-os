"""
Input validators for MCP tools

Provides validation functions for build_number and step_name parameters
to prevent invalid inputs and potential injection attacks.
"""

import re


def validate_build_number(build_number: int) -> dict | None:
    """
    Validate build_number parameter

    Args:
        build_number: Build number to validate

    Returns:
        dict: Error dict if invalid, None if valid
    """
    if not isinstance(build_number, int):
        return {"error": "build_number must be an integer", "provided": str(build_number)}

    if build_number < 1:
        return {"error": "build_number must be positive", "provided": build_number}

    if build_number > 999999:
        return {"error": "build_number exceeds maximum (999999)", "provided": build_number}

    return None


def validate_step_name(step_name: str) -> dict | None:
    """
    Validate step_name parameter

    Args:
        step_name: Step name to validate

    Returns:
        dict: Error dict if invalid, None if valid
    """
    if not isinstance(step_name, str):
        return {"error": "step_name must be a string", "provided": str(step_name)}

    if not step_name or not step_name.strip():
        return {"error": "step_name cannot be empty"}

    if len(step_name) > 200:
        return {"error": "step_name too long (max 200 chars)", "length": len(step_name)}

    # Sanitize potential injection patterns
    dangerous_patterns = [';', '&&', '||', '`', '$', '|', '>', '<', '\n', '\r']
    for pattern in dangerous_patterns:
        if pattern in step_name:
            return {"error": f"step_name contains dangerous character: {repr(pattern)}"}

    return None


def sanitize_error(error: Exception) -> str:
    """
    Remove sensitive credentials from error messages before logging

    Masks passwords, tokens, and app_passwords to prevent credential leakage
    in logs, screenshots, or CI/CD output.

    Args:
        error: Exception object to sanitize

    Returns:
        str: Sanitized error message with credentials masked
    """
    msg = str(error)

    # Mask various credential patterns
    msg = re.sub(r'password[=:\s]+[^\s,\)]+', 'password=***', msg, flags=re.IGNORECASE)
    msg = re.sub(r'token[=:\s]+[^\s,\)]+', 'token=***', msg, flags=re.IGNORECASE)
    msg = re.sub(r'app_password[=:\s]+[^\s,\)]+', 'app_password=***', msg, flags=re.IGNORECASE)
    msg = re.sub(r'api[_-]?key[=:\s]+[^\s,\)]+', 'api_key=***', msg, flags=re.IGNORECASE)
    msg = re.sub(r'secret[=:\s]+[^\s,\)]+', 'secret=***', msg, flags=re.IGNORECASE)

    return msg
