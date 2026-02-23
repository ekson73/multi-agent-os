"""
Free AI API Providers for Pipeline Diagnosis Enhancement

Manages round-robin access to free LLM APIs with context passing
for enhanced failure diagnosis beyond local pattern matching.

Supported Providers (all FREE tier):
- DeepSeek: GPT-4 equivalent quality, 60 req/min
- Gemini 2.0 Flash: Google's latest fast model, 1M tokens/min free
- Mistral Codestral 25.01: Code-specialized model, 20 req/min

Author: MAOS MCP Hub
Version: 1.1.0 (Updated 2025-11-05: Gemini 2.0, Mistral api.mistral.ai endpoint)
"""

import os
import httpx
import json
from typing import Optional, Dict, List
from datetime import datetime, timedelta


FREE_API_PROVIDERS = [
    {
        "name": "deepseek",
        "priority": 1,
        "endpoint": "https://api.deepseek.com/v1/chat/completions",
        "model": "deepseek-chat",
        "quality_score": 90,  # GPT-4 equivalent
        "rate_limit": {"requests_per_minute": 60, "tokens_per_minute": 10000},
        "requires_api_key": True,
        "env_var": "DEEPSEEK_API_KEY",
        "timeout": 30.0,
        "max_tokens_default": 500,
    },
    {
        "name": "gemini_flash",
        "priority": 2,
        "endpoint": "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent",
        "model": "gemini-2.0-flash-exp",
        "quality_score": 85,  # Gemini 2.0 has better reasoning
        "rate_limit": {
            "requests_per_minute": 15,
            "tokens_per_minute": 1000000,  # 1M free tier
        },
        "requires_api_key": True,
        "env_var": "GOOGLE_API_KEY",
        "timeout": 30.0,
        "max_tokens_default": 500,
    },
    {
        "name": "mistral_codestral",
        "priority": 3,
        "endpoint": "https://api.mistral.ai/v1/chat/completions",
        "model": "codestral-latest",
        "quality_score": 80,  # Codestral 25.01 has improved reasoning
        "rate_limit": {"requests_per_minute": 20, "tokens_per_minute": 5000},
        "requires_api_key": True,
        "env_var": "MISTRAL_API_KEY",
        "timeout": 30.0,
        "max_tokens_default": 500,
    },
]


class APIProviderManager:
    """
    Manages round-robin access to free AI API providers

    Features:
    - Automatic provider rotation (priority order)
    - Rate limit handling
    - Fallback to next provider on failure
    - Context-enriched prompting
    - Token usage tracking
    """

    def __init__(self):
        self.providers = FREE_API_PROVIDERS.copy()
        self.current_index = 0
        self.call_history = []  # Track calls for rate limiting
        self._initialize_providers()

    def _initialize_providers(self):
        """Initialize providers with API keys from environment"""
        for provider in self.providers:
            if provider["requires_api_key"]:
                api_key = os.getenv(provider["env_var"])
                provider["api_key"] = api_key
                provider["available"] = api_key is not None and len(api_key) > 0
            else:
                provider["available"] = True

    def get_next_available(self) -> Optional[Dict]:
        """
        Get next available provider in round-robin order

        Returns:
            Provider dict or None if all providers unavailable

        Example:
            >>> manager = APIProviderManager()
            >>> provider = manager.get_next_available()
            >>> provider["name"]
            'deepseek'
        """
        attempts = 0
        max_attempts = len(self.providers)

        while attempts < max_attempts:
            provider = self.providers[self.current_index]
            self.current_index = (self.current_index + 1) % len(self.providers)
            attempts += 1

            if provider["available"] and not self._is_rate_limited(provider):
                return provider

        return None  # No providers available

    def _is_rate_limited(self, provider: Dict) -> bool:
        """
        Check if provider is currently rate limited

        Args:
            provider: Provider configuration dict

        Returns:
            True if rate limited, False otherwise
        """
        now = datetime.utcnow()
        one_minute_ago = now - timedelta(minutes=1)

        # Count recent calls to this provider
        recent_calls = [
            call
            for call in self.call_history
            if call["provider"] == provider["name"]
            and call["timestamp"] > one_minute_ago
        ]

        rate_limit = provider["rate_limit"]["requests_per_minute"]
        return len(recent_calls) >= rate_limit

    def _record_call(self, provider: Dict, tokens_used: int):
        """Record API call for rate limit tracking"""
        self.call_history.append(
            {
                "provider": provider["name"],
                "timestamp": datetime.utcnow(),
                "tokens_used": tokens_used,
            }
        )

        # Clean up old history (> 5 minutes)
        five_minutes_ago = datetime.utcnow() - timedelta(minutes=5)
        self.call_history = [
            call for call in self.call_history if call["timestamp"] > five_minutes_ago
        ]

    async def call_api(
        self, provider: Dict, prompt: str, max_tokens: int = 500
    ) -> Dict:
        """
        Call specific provider's API

        Args:
            provider: Provider configuration dict
            prompt: User prompt for LLM
            max_tokens: Maximum tokens in response

        Returns:
            {
                "provider": "deepseek",
                "content": "AI response text",
                "tokens_used": 234,
                "success": true
            }

        Raises:
            httpx.HTTPStatusError: If API call fails
            httpx.TimeoutException: If request times out
        """
        if provider["name"] == "deepseek":
            return await self._call_deepseek(provider, prompt, max_tokens)
        elif provider["name"] == "gemini_flash":
            return await self._call_gemini(provider, prompt, max_tokens)
        elif provider["name"] == "mistral_codestral":
            return await self._call_mistral(provider, prompt, max_tokens)
        else:
            raise ValueError(f"Unknown provider: {provider['name']}")

    async def _call_deepseek(
        self, provider: Dict, prompt: str, max_tokens: int
    ) -> Dict:
        """
        Call DeepSeek API (OpenAI-compatible)

        Endpoint: https://api.deepseek.com/v1/chat/completions
        Docs: https://platform.deepseek.com/api-docs/
        """
        async with httpx.AsyncClient(timeout=provider["timeout"]) as client:
            response = await client.post(
                provider["endpoint"],
                headers={
                    "Authorization": f"Bearer {provider['api_key']}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": provider["model"],
                    "messages": [
                        {
                            "role": "system",
                            "content": "You are a DevOps expert specializing in CI/CD pipeline troubleshooting. Provide concise, actionable analysis.",
                        },
                        {"role": "user", "content": prompt},
                    ],
                    "max_tokens": max_tokens,
                    "temperature": 0.3,  # Low temp for deterministic analysis
                },
            )

            response.raise_for_status()
            data = response.json()

            tokens_used = data.get("usage", {}).get("total_tokens", 0)
            self._record_call(provider, tokens_used)

            return {
                "provider": "deepseek",
                "content": data["choices"][0]["message"]["content"],
                "tokens_used": tokens_used,
                "success": True,
            }

    async def _call_gemini(
        self, provider: Dict, prompt: str, max_tokens: int
    ) -> Dict:
        """
        Call Google Gemini 2.0 Flash API

        Endpoint: https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent
        Docs: https://ai.google.dev/gemini-api/docs
        Note: Gemini 1.5 deprecated in 2025, migrated to 2.0
        """
        async with httpx.AsyncClient(timeout=provider["timeout"]) as client:
            response = await client.post(
                f"{provider['endpoint']}?key={provider['api_key']}",
                headers={"Content-Type": "application/json"},
                json={
                    "contents": [{"parts": [{"text": prompt}]}],
                    "generationConfig": {
                        "temperature": 0.3,
                        "maxOutputTokens": max_tokens,
                    },
                },
            )

            response.raise_for_status()
            data = response.json()

            # Gemini response format
            content = data["candidates"][0]["content"]["parts"][0]["text"]
            tokens_used = data.get("usageMetadata", {}).get("totalTokenCount", 0)

            self._record_call(provider, tokens_used)

            return {
                "provider": "gemini_flash",
                "content": content,
                "tokens_used": tokens_used,
                "success": True,
            }

    async def _call_mistral(
        self, provider: Dict, prompt: str, max_tokens: int
    ) -> Dict:
        """
        Call Mistral Codestral API

        Endpoint: https://api.mistral.ai/v1/chat/completions
        Docs: https://docs.mistral.ai/api/
        Note: Using api.mistral.ai (not codestral.mistral.ai) for general app access
        """
        async with httpx.AsyncClient(timeout=provider["timeout"]) as client:
            response = await client.post(
                provider["endpoint"],
                headers={
                    "Authorization": f"Bearer {provider['api_key']}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": provider["model"],
                    "messages": [
                        {
                            "role": "system",
                            "content": "You are a DevOps expert. Analyze CI/CD failures concisely.",
                        },
                        {"role": "user", "content": prompt},
                    ],
                    "max_tokens": max_tokens,
                    "temperature": 0.3,
                },
            )

            response.raise_for_status()
            data = response.json()

            tokens_used = data.get("usage", {}).get("total_tokens", 0)
            self._record_call(provider, tokens_used)

            return {
                "provider": "mistral_codestral",
                "content": data["choices"][0]["message"]["content"],
                "tokens_used": tokens_used,
                "success": True,
            }

    async def diagnose_with_fallback(
        self, prompt: str, max_attempts: int = 3
    ) -> Dict:
        """
        Call APIs with automatic fallback to next provider on failure

        Args:
            prompt: Enriched prompt with context
            max_attempts: Maximum providers to try (default: 3)

        Returns:
            {
                "success": true,
                "provider": "deepseek",
                "content": "...",
                "tokens_used": 234,
                "attempts": 1
            }

        Example:
            >>> manager = APIProviderManager()
            >>> result = await manager.diagnose_with_fallback("Analyze this error...")
            >>> result["success"]
            True
        """
        attempts = 0

        while attempts < max_attempts:
            provider = self.get_next_available()

            if not provider:
                return {
                    "success": False,
                    "error": "No API providers available",
                    "reason": "All providers are unavailable or rate limited",
                    "attempts": attempts,
                }

            try:
                result = await self.call_api(provider, prompt)
                result["attempts"] = attempts + 1
                return result

            except httpx.HTTPStatusError as e:
                attempts += 1
                if e.response.status_code == 429:  # Rate limit
                    # Try next provider
                    continue
                elif attempts >= max_attempts:
                    return {
                        "success": False,
                        "error": f"HTTP {e.response.status_code}",
                        "provider": provider["name"],
                        "attempts": attempts,
                    }
                else:
                    continue

            except httpx.TimeoutException:
                attempts += 1
                if attempts >= max_attempts:
                    return {
                        "success": False,
                        "error": "Timeout",
                        "provider": provider["name"],
                        "attempts": attempts,
                    }
                continue

            except Exception as e:
                attempts += 1
                if attempts >= max_attempts:
                    return {
                        "success": False,
                        "error": str(e),
                        "provider": provider.get("name", "unknown"),
                        "attempts": attempts,
                    }
                continue

        return {
            "success": False,
            "error": "Max attempts exceeded",
            "attempts": attempts,
        }

    def get_stats(self) -> Dict:
        """
        Get usage statistics

        Returns:
            {
                "total_calls": 42,
                "calls_by_provider": {...},
                "total_tokens": 12345,
                "available_providers": 3
            }
        """
        calls_by_provider = {}
        total_tokens = 0

        for call in self.call_history:
            provider = call["provider"]
            calls_by_provider[provider] = calls_by_provider.get(provider, 0) + 1
            total_tokens += call.get("tokens_used", 0)

        available_count = sum(1 for p in self.providers if p["available"])

        return {
            "total_calls": len(self.call_history),
            "calls_by_provider": calls_by_provider,
            "total_tokens": total_tokens,
            "available_providers": available_count,
            "configured_providers": [
                {
                    "name": p["name"],
                    "available": p["available"],
                    "quality_score": p["quality_score"],
                }
                for p in self.providers
            ],
        }


def build_enriched_prompt(
    build_number: int,
    step_name: str,
    branch: str,
    error_log: str,
    local_analysis: Dict,
) -> str:
    """
    Build context-enriched prompt for AI analysis

    Includes local pattern matching results as context
    to improve AI analysis quality.

    Args:
        build_number: Build number
        step_name: Failed step name
        branch: Git branch
        error_log: Truncated error logs (last 100 lines)
        local_analysis: Results from local hybrid analysis

    Returns:
        Enriched prompt string with structured context

    Example:
        >>> prompt = build_enriched_prompt(42, "Build", "develop", "...", {...})
        >>> "LOCAL ANALYSIS" in prompt
        True
    """
    prompt = f"""Analyze this CI/CD pipeline failure and provide enhanced diagnosis.

BUILD INFORMATION:
- Build Number: {build_number}
- Step Name: {step_name}
- Branch: {branch}

LOCAL ANALYSIS (already performed):
- Error Type: {local_analysis['diagnosis']['error_type']}
- Confidence: {local_analysis['diagnosis']['confidence']:.0%}
- Severity: {local_analysis['diagnosis']['severity']}
- Category: {local_analysis['diagnosis']['category']}
- Root Cause Hypothesis: {local_analysis['diagnosis']['root_cause_hypothesis']}

IMMEDIATE ACTIONS (from pattern matching):
{chr(10).join(f"- {action}" for action in local_analysis['immediate_actions'][:3])}

ERROR LOG (last 100 lines):
```
{error_log}
```

YOUR TASK:
1. **Validate** if local analysis is correct (error type, severity, root cause)
2. **Provide** ADDITIONAL insights not covered by local pattern matching
3. **Suggest** alternative diagnosis if local analysis seems incorrect or incomplete
4. **Focus** on ROOT CAUSE, not just symptoms
5. **Be** concise and actionable (max 200 words)

RESPOND IN JSON FORMAT:
{{
  "validates_local_analysis": true/false,
  "validation_notes": "Brief explanation if false",
  "additional_insights": [
    "Insight 1: ...",
    "Insight 2: ..."
  ],
  "root_cause": "Detailed root cause explanation (2-3 sentences)",
  "confidence_adjustment": 0.0,  // +0.1 to +0.3 if more confident, -0.1 to -0.3 if less confident
  "alternative_diagnosis": "Only if local analysis is wrong, suggest correct error type",
  "recommended_priority": "immediate/high/medium"
}}

IMPORTANT:
- If local analysis is correct, validate it and add insights
- If incorrect, explain why and provide alternative
- Focus on what local patterns might have missed
- Be specific and actionable
"""

    return prompt
