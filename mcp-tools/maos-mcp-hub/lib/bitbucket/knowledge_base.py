"""
Knowledge Base for Auto-Learning from Successful Fixes

Persistent storage for learned patterns with fuzzy matching,
confidence scoring, and organic knowledge growth.

Author: MAOS MCP Hub
Version: 1.0.0
"""

import json
from pathlib import Path
from datetime import datetime, timezone
from typing import List, Dict, Optional


# Knowledge base file location
KNOWLEDGE_BASE_FILE = Path(__file__).parent.parent / "data" / "learned_patterns.json"


class KnowledgeBase:
    """
    Persistent storage for learned error patterns and successful fixes

    Features:
    - Fuzzy pattern matching (85% similarity threshold)
    - Confidence scoring based on success/failure ratio
    - Automatic pattern consolidation
    - Organic knowledge growth
    - Track fix history and reuse

    Example:
        >>> kb = KnowledgeBase()
        >>> kb.add_successful_fix(
        ...     build_number=42,
        ...     error_signature="test_failure:hash123",
        ...     error_type="test_failure",
        ...     solution_applied={"description": "Fixed test data", "fix_type": "manual"},
        ...     metadata={"branch": "develop"}
        ... )
        >>> results = kb.search("test_failure:hash456")
        >>> len(results) > 0
        True
    """

    def __init__(self):
        """Initialize knowledge base from disk"""
        self.patterns = self._load()

    def _load(self) -> List[dict]:
        """
        Load patterns from disk

        Returns:
            List of pattern dicts, or [] if file doesn't exist

        Creates:
            - Parent directory if needed
            - Empty JSON file if needed
        """
        if not KNOWLEDGE_BASE_FILE.exists():
            KNOWLEDGE_BASE_FILE.parent.mkdir(parents=True, exist_ok=True)
            KNOWLEDGE_BASE_FILE.write_text("[]")
            return []

        try:
            with open(KNOWLEDGE_BASE_FILE) as f:
                return json.load(f)
        except json.JSONDecodeError:
            # Corrupted file, reset
            KNOWLEDGE_BASE_FILE.write_text("[]")
            return []

    def _save(self):
        """
        Persist patterns to disk

        Writes:
            - Formatted JSON with 2-space indent
            - Atomic write (write to temp, then rename)
        """
        temp_file = KNOWLEDGE_BASE_FILE.with_suffix(".tmp")

        with open(temp_file, "w") as f:
            json.dump(self.patterns, f, indent=2, ensure_ascii=False)

        # Atomic rename
        temp_file.replace(KNOWLEDGE_BASE_FILE)

    def add_successful_fix(
        self,
        build_number: int,
        error_signature: str,
        error_type: str,
        solution_applied: dict,
        metadata: dict,
    ):
        """
        Save successful fix to knowledge base

        Args:
            build_number: Build that was fixed
            error_signature: Unique signature (e.g., "test_failure:hash123")
            error_type: Category (test_failure, dependency_conflict, etc.)
            solution_applied: {
                "description": "What was done",
                "fix_type": "config" | "dependency" | "code" | "manual",
                "applied_by": "admin" | "auto",
                "applied_at": ISO timestamp
            }
            metadata: Additional context {
                "branch": "develop",
                "commit": "abc1234",
                "step_name": "Build and Test"
            }

        Side Effects:
            - If similar pattern exists (≥85% similarity), increments its success_count
            - Otherwise, adds new pattern to knowledge base
            - Saves to disk

        Example:
            >>> kb = KnowledgeBase()
            >>> kb.add_successful_fix(
            ...     build_number=42,
            ...     error_signature="timeout:hash789",
            ...     error_type="timeout",
            ...     solution_applied={
            ...         "description": "Increased timeout from 30 to 60 minutes",
            ...         "fix_type": "config",
            ...         "applied_by": "admin",
            ...         "applied_at": "2025-01-04T12:00:00Z"
            ...     },
            ...     metadata={"branch": "develop", "commit": "abc1234"}
            ... )
        """
        # Check for similar patterns (fuzzy match)
        similar = self._find_similar(error_signature, threshold=0.85)

        if similar:
            # Increment success count for existing pattern
            similar["success_count"] += 1
            similar["last_used"] = datetime.now(timezone.utc).isoformat()
            similar["builds_fixed"].append(build_number)
            similar["confidence"] = similar["success_count"] / (
                similar["success_count"] + similar["failure_count"]
            )

            # Update solution if newer one is better (manual override)
            if solution_applied.get("fix_type") != "auto" or similar.get(
                "solutions", [{}]
            )[0].get("fix_type") == "auto":
                similar["solutions"].append(solution_applied)
        else:
            # Add new pattern
            pattern = {
                "id": len(self.patterns) + 1,
                "error_signature": error_signature,
                "error_type": error_type,
                "solutions": [solution_applied],
                "metadata": metadata,
                "success_count": 1,
                "failure_count": 0,
                "confidence": 1.0,
                "first_seen": datetime.now(timezone.utc).isoformat(),
                "last_used": datetime.now(timezone.utc).isoformat(),
                "builds_fixed": [build_number],
            }
            self.patterns.append(pattern)

        self._save()

    def mark_fix_failed(self, error_signature: str):
        """
        Mark that a fix didn't work (decrease confidence)

        Args:
            error_signature: Error signature that fix failed for

        Side Effects:
            - Increments failure_count for matching pattern
            - Recalculates confidence score
            - Saves to disk

        Example:
            >>> kb = KnowledgeBase()
            >>> kb.mark_fix_failed("test_failure:hash123")
        """
        similar = self._find_similar(error_signature, threshold=0.85)

        if similar:
            similar["failure_count"] += 1
            similar["confidence"] = similar["success_count"] / (
                similar["success_count"] + similar["failure_count"]
            )
            self._save()

    def search(self, query: str, min_confidence: float = 0.5, min_similarity: float = 0.6) -> List[dict]:
        """
        Search for matching patterns with similarity scoring

        Supports two query modes:
        1. Error signature format: "timeout:hash123" (exact matching)
        2. Free text format: "timeout error" or "test failure" (semantic matching)

        Args:
            query: Error signature OR free text description
            min_confidence: Minimum confidence threshold (default: 0.5)
            min_similarity: Minimum similarity threshold (default: 0.6)
                           0.6 = same error_type but different hash
                           0.7 = same error_type with some hash overlap
                           1.0 = exact match

        Returns:
            List of patterns sorted by (confidence × similarity) descending

        Example:
            >>> kb = KnowledgeBase()
            >>> # Signature-based search
            >>> results = kb.search("timeout:hash123", min_confidence=0.5)
            >>> # Free text search
            >>> results = kb.search("timeout error", min_confidence=0.5)
            >>> results[0]["similarity"]
            0.70  # Found timeout patterns
        """
        results = []

        # Detect query type and normalize
        is_signature = ':' in query

        if not is_signature:
            # Free text query - extract error type keywords
            normalized_query = self._normalize_free_text_query(query)
        else:
            normalized_query = query

        for pattern in self.patterns:
            if is_signature:
                # Signature-based matching (original logic)
                similarity = self._calculate_similarity(
                    normalized_query, pattern["error_signature"]
                )
            else:
                # Free text matching (semantic)
                similarity = self._calculate_free_text_similarity(
                    normalized_query, pattern
                )

            if similarity >= min_similarity and pattern["confidence"] >= min_confidence:
                results.append({**pattern, "similarity": similarity})

        # Sort by confidence × similarity (weighted score)
        results.sort(key=lambda x: x["confidence"] * x["similarity"], reverse=True)
        return results

    def _normalize_free_text_query(self, text: str) -> str:
        """
        Normalize free text query to extract error type

        Args:
            text: Free text like "timeout error" or "test failure"

        Returns:
            Normalized error_type keyword(s)

        Example:
            >>> kb = KnowledgeBase()
            >>> kb._normalize_free_text_query("timeout error in step")
            'timeout'
            >>> kb._normalize_free_text_query("test failure")
            'test'
        """
        # Convert to lowercase and extract keywords
        text = text.lower().strip()

        # Known error type patterns
        error_types = {
            'timeout': ['timeout', 'timed out', 'time limit'],
            'test': ['test', 'junit', 'pytest', 'assertion'],
            'compilation': ['compilation', 'compile', 'syntax'],
            'dependency': ['dependency', 'maven', 'npm', 'artifact'],
            'memory': ['memory', 'heap', 'oom', 'outofmemory'],
            'network': ['network', 'connection', 'dns'],
            'permission': ['permission', 'access', 'denied', 'auth'],
            'docker': ['docker', 'container', 'image'],
        }

        # Find matching error types
        for error_type, keywords in error_types.items():
            for keyword in keywords:
                if keyword in text:
                    return error_type

        # Return first word if no match (fallback)
        words = text.split()
        return words[0] if words else text

    def _calculate_free_text_similarity(self, normalized_query: str, pattern: dict) -> float:
        """
        Calculate similarity between free text query and pattern

        Args:
            normalized_query: Normalized error type from free text
            pattern: Pattern dict with error_signature and error_type

        Returns:
            Similarity score 0.0-1.0

        Example:
            >>> kb = KnowledgeBase()
            >>> pattern = {"error_type": "timeout", "error_signature": "timeout:hash123"}
            >>> kb._calculate_free_text_similarity("timeout", pattern)
            0.8  # High match for error type
        """
        pattern_error_type = pattern["error_signature"].split(':')[0] if ':' in pattern["error_signature"] else pattern.get("error_type", "")

        # Exact error_type match
        if normalized_query == pattern_error_type:
            return 0.8  # High match for same error type

        # Partial match (substring)
        if normalized_query in pattern_error_type or pattern_error_type in normalized_query:
            return 0.6  # Medium match

        # Check if query words appear in pattern metadata
        pattern_text = f"{pattern.get('error_type', '')} {pattern_error_type}".lower()
        if any(word in pattern_text for word in normalized_query.split()):
            return 0.5  # Low match

        return 0.0  # No match

    def _find_similar(
        self, error_signature: str, threshold: float = 0.75
    ) -> Optional[dict]:
        """
        Find similar pattern above threshold

        Args:
            error_signature: Error signature to match
            threshold: Similarity threshold (default: 0.75)
                      0.75 = consolidate patterns with same error_type and high hash overlap
                      0.85 = only consolidate near-identical patterns

        Returns:
            First matching pattern or None

        Algorithm:
            Uses improved Jaccard similarity with error_type weighting and character bigrams
        """
        for pattern in self.patterns:
            similarity = self._calculate_similarity(
                error_signature, pattern["error_signature"]
            )
            if similarity >= threshold:
                return pattern
        return None

    def _calculate_similarity(self, sig1: str, sig2: str) -> float:
        """
        Calculate similarity between two error signatures

        Algorithm: Jaccard similarity with improved tokenization
        - Split by : to separate error_type from hash
        - Use character-level tokens for better fuzzy matching

        Args:
            sig1: First signature (e.g., "timeout:12ab34cd")
            sig2: Second signature (e.g., "timeout:99zz88yy")

        Returns:
            Similarity score 0.0-1.0

        Example:
            >>> kb = KnowledgeBase()
            >>> kb._calculate_similarity("timeout:12ab34cd", "timeout:99zz88yy")
            0.5  # Same error_type (timeout) = 50% base similarity
        """
        # Split by : to get error_type and hash separately
        parts1 = sig1.split(':')
        parts2 = sig2.split(':')

        if not parts1 or not parts2:
            return 0.0

        # If error_type matches, start with 50% base similarity
        error_type_match = parts1[0] == parts2[0]
        base_similarity = 0.5 if error_type_match else 0.0

        # If only error_type (no hash), use exact match
        if len(parts1) == 1 and len(parts2) == 1:
            return 1.0 if error_type_match else 0.0

        # If one has hash and other doesn't, return base similarity
        if len(parts1) != len(parts2):
            return base_similarity

        # Compare hashes using character n-grams (bigrams)
        if len(parts1) > 1 and len(parts2) > 1:
            hash1 = parts1[1]
            hash2 = parts2[1]

            # Create character bigrams for fuzzy matching
            bigrams1 = set(hash1[i:i+2] for i in range(len(hash1)-1))
            bigrams2 = set(hash2[i:i+2] for i in range(len(hash2)-1))

            if bigrams1 and bigrams2:
                intersection = bigrams1.intersection(bigrams2)
                union = bigrams1.union(bigrams2)
                hash_similarity = len(intersection) / len(union)

                # Weighted average: 70% error_type + 30% hash
                return (0.7 if error_type_match else 0.0) + (0.3 * hash_similarity)

        return base_similarity

    def get_stats(self) -> dict:
        """
        Get knowledge base statistics

        Returns:
            {
                "total_patterns": 47,
                "total_fixes_applied": 123,
                "average_confidence": 0.87,
                "error_type_distribution": {
                    "test_failure": 15,
                    "dependency_conflict": 12,
                    ...
                },
                "fix_type_distribution": {
                    "config": 25,
                    "dependency": 10,
                    "code": 5,
                    "manual": 7
                },
                "top_solutions": [
                    {
                        "error_type": "timeout",
                        "solution": "Increase timeout",
                        "success_count": 12
                    },
                    ...
                ]
            }

        Example:
            >>> kb = KnowledgeBase()
            >>> stats = kb.get_stats()
            >>> stats["total_patterns"]
            47
        """
        total_patterns = len(self.patterns)
        total_fixes = sum(p["success_count"] for p in self.patterns)
        avg_confidence = (
            sum(p["confidence"] for p in self.patterns) / total_patterns
            if total_patterns
            else 0
        )

        # Error type distribution
        error_dist = {}
        for pattern in self.patterns:
            error_type = pattern["error_type"]
            error_dist[error_type] = error_dist.get(error_type, 0) + 1

        # Fix type distribution
        fix_dist = {}
        for pattern in self.patterns:
            for solution in pattern.get("solutions", []):
                fix_type = solution.get("fix_type", "unknown")
                fix_dist[fix_type] = fix_dist.get(fix_type, 0) + 1

        # Top solutions (by success count)
        top_solutions = []
        for pattern in sorted(
            self.patterns, key=lambda p: p["success_count"], reverse=True
        )[:5]:
            if pattern["solutions"]:
                top_solutions.append(
                    {
                        "error_type": pattern["error_type"],
                        "solution": pattern["solutions"][0].get(
                            "description", "N/A"
                        ),
                        "success_count": pattern["success_count"],
                        "confidence": pattern["confidence"],
                    }
                )

        return {
            "total_patterns": total_patterns,
            "total_fixes_applied": total_fixes,
            "average_confidence": avg_confidence,
            "error_type_distribution": error_dist,
            "fix_type_distribution": fix_dist,
            "top_solutions": top_solutions,
            "knowledge_base_file": str(KNOWLEDGE_BASE_FILE),
        }

    def get_pattern_by_id(self, pattern_id: int) -> Optional[dict]:
        """
        Get pattern by ID

        Args:
            pattern_id: Pattern ID

        Returns:
            Pattern dict or None

        Example:
            >>> kb = KnowledgeBase()
            >>> pattern = kb.get_pattern_by_id(1)
            >>> pattern["error_type"]
            'test_failure'
        """
        for pattern in self.patterns:
            if pattern["id"] == pattern_id:
                return pattern
        return None

    def delete_pattern(self, pattern_id: int) -> bool:
        """
        Delete pattern by ID

        Args:
            pattern_id: Pattern ID to delete

        Returns:
            True if deleted, False if not found

        Side Effects:
            - Removes pattern from memory
            - Saves to disk

        Example:
            >>> kb = KnowledgeBase()
            >>> kb.delete_pattern(5)
            True
        """
        for i, pattern in enumerate(self.patterns):
            if pattern["id"] == pattern_id:
                del self.patterns[i]
                self._save()
                return True
        return False

    def export_patterns(self, error_type: Optional[str] = None) -> List[dict]:
        """
        Export patterns for backup or analysis

        Args:
            error_type: Optional filter by error type

        Returns:
            List of pattern dicts

        Example:
            >>> kb = KnowledgeBase()
            >>> timeout_patterns = kb.export_patterns(error_type="timeout")
            >>> len(timeout_patterns)
            5
        """
        if error_type:
            return [p for p in self.patterns if p["error_type"] == error_type]
        return self.patterns.copy()

    def import_patterns(self, patterns: List[dict], merge: bool = True):
        """
        Import patterns from backup or external source

        Args:
            patterns: List of pattern dicts to import
            merge: If True, merge with existing; if False, replace

        Side Effects:
            - Updates patterns in memory
            - Saves to disk

        Example:
            >>> kb = KnowledgeBase()
            >>> backup_patterns = [...]  # Load from backup
            >>> kb.import_patterns(backup_patterns, merge=True)
        """
        if merge:
            # Merge with existing patterns
            existing_signatures = {p["error_signature"] for p in self.patterns}

            for pattern in patterns:
                if pattern["error_signature"] not in existing_signatures:
                    # Assign new ID
                    pattern["id"] = len(self.patterns) + 1
                    self.patterns.append(pattern)
        else:
            # Replace all patterns
            self.patterns = patterns

        self._save()
