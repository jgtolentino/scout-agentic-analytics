"""
DataOS Documentation Extractor & Diff Engine
Production-grade documentation extraction, archiving, and version comparison
"""

from .main import (
    DataOSDocsExtractor,
    DocumentExtractor,
    DiffEngine,
    ChangeAnalyzer,
    NotificationService,
    ExtractionConfig,
    ExtractionMethod,
    DiffMode,
    OutputFormat,
    ArchiveMetadata,
    DiffResult
)

__version__ = "1.0.0"
__author__ = "TBWA Engineering"
__description__ = "Automated extraction, archiving, and version comparison of web-based documentation"

__all__ = [
    "DataOSDocsExtractor",
    "DocumentExtractor",
    "DiffEngine",
    "ChangeAnalyzer",
    "NotificationService",
    "ExtractionConfig",
    "ExtractionMethod",
    "DiffMode",
    "OutputFormat",
    "ArchiveMetadata",
    "DiffResult"
]