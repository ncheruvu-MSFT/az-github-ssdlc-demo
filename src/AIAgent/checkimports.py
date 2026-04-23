# =============================================================================
# Import Validation — Verify all AI Agent modules import cleanly
# SSDLC: Used by all 4 pipeline patterns (P1-P4) as a build gate
# =============================================================================
"""Validate that all Python modules in the AI Agent package import without errors."""

import importlib
import os
import sys
from typing import NamedTuple


class ImportResult(NamedTuple):
    module: str
    success: bool
    error: str


def check_imports(source_dir: str | None = None) -> list[ImportResult]:
    """Check that all .py files in the agent source directory import cleanly.

    Args:
        source_dir: Path to the AIAgent source directory.
                    Defaults to the directory containing this script.

    Returns:
        List of ImportResult for each module checked.
    """
    if source_dir is None:
        source_dir = os.path.dirname(os.path.abspath(__file__))

    if source_dir not in sys.path:
        sys.path.insert(0, source_dir)

    results: list[ImportResult] = []
    for filename in sorted(os.listdir(source_dir)):
        if not filename.endswith(".py") or filename.startswith("_"):
            continue

        module_name = filename[:-3]
        try:
            importlib.import_module(module_name)
            results.append(ImportResult(module=module_name, success=True, error=""))
            print(f"  ✓ {module_name}")
        except Exception as exc:
            results.append(
                ImportResult(module=module_name, success=False, error=str(exc))
            )
            print(f"  ✗ {module_name}: {exc}")

    return results


def validate_required_modules(results: list[ImportResult]) -> bool:
    """Ensure core modules are present and importable.

    Args:
        results: Import results to check.

    Returns:
        True if all required modules imported successfully.
    """
    required = {
        "create_agent",
        "run_agent",
        "agent_eval",
        "red_team",
        "observability",
        "agenteval_classic",
        "content_safety",
        "redteam_classic",
        "e2etest",
        "policy_validation",
        "tool_schema_validation",
        "gate_logic",
    }
    imported = {r.module for r in results if r.success}
    missing = required - imported
    if missing:
        print(f"\nMissing required modules: {', '.join(sorted(missing))}")
        return False
    return True


if __name__ == "__main__":
    print("Checking AI Agent module imports...")
    results = check_imports()

    passed = sum(1 for r in results if r.success)
    failed = sum(1 for r in results if not r.success)
    print(f"\nResults: {passed} passed, {failed} failed out of {len(results)} modules")

    if not validate_required_modules(results):
        sys.exit(1)

    if failed > 0:
        print("Import validation FAILED")
        sys.exit(1)

    print("Import validation PASSED")
    sys.exit(0)
