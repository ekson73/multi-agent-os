"""
L8 memory substrate (WT5 / S4) — mem0 default, file/seed degradation.

See ``substrate.py`` for the full contract.
"""

from .substrate import (
    FileSeedBackend,
    Mem0Backend,
    MemoryRecord,
    MemorySubstrate,
    SCHEMA_VERSION,
)

__all__ = [
    "FileSeedBackend",
    "Mem0Backend",
    "MemoryRecord",
    "MemorySubstrate",
    "SCHEMA_VERSION",
]
