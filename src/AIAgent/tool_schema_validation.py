# =============================================================================
# Tool Schema Validation — P4 Agent + MCP Tools Pipeline
# SSDLC: MCP tool JSON schema validation, permission scope checks, contract tests
# Ref: Image Row 4 — BUILD (Job 1: Tool Schema Val.)
# =============================================================================
"""Validate MCP tool schemas, permission scopes, and interface contracts."""

import json
import os
import sys
from pathlib import Path


def validate_tool_schemas() -> dict:
    """Validate all MCP tool JSON schemas in the config directory.

    Checks:
    - JSON schema validity for each tool definition
    - Required fields: name, description, inputSchema
    - Permission scopes are properly declared
    - No overly broad permissions (e.g., admin/*)
    - Tool interface contracts match expected patterns

    Returns:
        dict with status, errors, warnings, and tool count.
    """
    script_dir = Path(os.path.dirname(os.path.abspath(__file__)))
    tools_dir = script_dir / "config" / "tools"

    errors: list[str] = []
    warnings: list[str] = []
    tools_validated = 0

    if not tools_dir.exists():
        print(f"Tools directory not found: {tools_dir}")
        print("Creating default MCP tool schemas...")
        tools_dir.mkdir(parents=True, exist_ok=True)
        _create_default_tool_schemas(tools_dir)

    # Validate each tool schema
    for schema_file in sorted(tools_dir.glob("*.json")):
        print(f"  Validating: {schema_file.name}")
        tool_errors, tool_warnings = _validate_single_tool(schema_file)
        errors.extend(tool_errors)
        warnings.extend(tool_warnings)
        tools_validated += 1

    if tools_validated == 0:
        warnings.append("No tool schemas found to validate")

    passed = len(errors) == 0

    print("\nTool Schema Validation Results:")
    print(f"  Tools validated: {tools_validated}")
    print(f"  Errors: {len(errors)}")
    print(f"  Warnings: {len(warnings)}")
    print(f"  Overall: {'PASSED' if passed else 'FAILED'}")

    for e in errors:
        print(f"  ✗ ERROR: {e}")
    for w in warnings:
        print(f"  ⚠ WARN: {w}")

    return {
        "status": "passed" if passed else "failed",
        "tools_validated": tools_validated,
        "errors": errors,
        "warnings": warnings,
    }


def validate_tool_permissions() -> dict:
    """Check tool permission scopes for least-privilege compliance.

    Ref: Image Row 4 — BUILD → Check tool permission scopes

    Returns:
        dict with status and permission analysis.
    """
    script_dir = Path(os.path.dirname(os.path.abspath(__file__)))
    tools_dir = script_dir / "config" / "tools"

    if not tools_dir.exists():
        return {"status": "skipped", "reason": "No tools directory"}

    errors: list[str] = []
    warnings: list[str] = []
    permission_report: list[dict] = []

    for schema_file in sorted(tools_dir.glob("*.json")):
        try:
            with open(schema_file) as f:
                tool = json.load(f)
        except json.JSONDecodeError:
            continue

        name = tool.get("name", schema_file.stem)
        permissions = tool.get("permissions", [])

        # Check for overly broad permissions
        dangerous_patterns = [
            "admin:*",
            "*:*",
            "write:*",
            "execute:*",
            "root",
        ]
        for perm in permissions:
            scope = perm.get("scope", "")
            for pattern in dangerous_patterns:
                if pattern in scope:
                    errors.append(
                        f"Tool '{name}' has overly broad permission: '{scope}'"
                    )

        # Check for missing permission declarations
        if not permissions:
            warnings.append(f"Tool '{name}' has no permissions declared")

        permission_report.append({
            "tool": name,
            "permissions": permissions,
            "permission_count": len(permissions),
        })

    passed = len(errors) == 0

    print("\nTool Permission Audit:")
    print(f"  Tools checked: {len(permission_report)}")
    print(f"  Permission errors: {len(errors)}")
    print(f"  Overall: {'PASSED' if passed else 'FAILED'}")

    return {
        "status": "passed" if passed else "failed",
        "report": permission_report,
        "errors": errors,
        "warnings": warnings,
    }


def _validate_single_tool(schema_file: Path) -> tuple[list[str], list[str]]:
    """Validate a single MCP tool schema file."""
    errors: list[str] = []
    warnings: list[str] = []
    filename = schema_file.name

    try:
        with open(schema_file) as f:
            tool = json.load(f)
    except json.JSONDecodeError as exc:
        return [f"{filename}: Invalid JSON: {exc}"], []

    if not isinstance(tool, dict):
        return [f"{filename}: Root must be an object"], []

    # Required fields
    required = ["name", "description", "inputSchema"]
    for field in required:
        if field not in tool:
            errors.append(f"{filename}: Missing required field '{field}'")

    # Name validation
    name = tool.get("name", "")
    if name and not name.replace("_", "").replace("-", "").isalnum():
        warnings.append(
            f"{filename}: Tool name '{name}' contains special characters"
        )

    # Description quality
    desc = tool.get("description", "")
    if desc and len(desc) < 10:
        warnings.append(f"{filename}: Description too short ({len(desc)} chars)")

    # InputSchema validation
    input_schema = tool.get("inputSchema")
    if isinstance(input_schema, dict):
        if input_schema.get("type") != "object":
            errors.append(
                f"{filename}: inputSchema.type must be 'object', "
                f"got '{input_schema.get('type')}'"
            )

        properties = input_schema.get("properties", {})
        if not properties:
            warnings.append(f"{filename}: inputSchema has no properties")

        # Check that required inputs are in properties
        required_inputs = input_schema.get("required", [])
        for req in required_inputs:
            if req not in properties:
                errors.append(
                    f"{filename}: Required input '{req}' not in properties"
                )
    elif input_schema is not None:
        errors.append(f"{filename}: inputSchema must be an object")

    # OutputSchema validation (optional but recommended)
    if "outputSchema" not in tool:
        warnings.append(f"{filename}: No outputSchema defined (recommended)")

    return errors, warnings


def _create_default_tool_schemas(tools_dir: Path) -> None:
    """Create example MCP tool schemas for the SSDLC agent."""
    code_review_tool = {
        "name": "ssdlc_code_review",
        "description": "Review code for security vulnerabilities using OWASP Top 10 patterns",
        "inputSchema": {
            "type": "object",
            "properties": {
                "code": {
                    "type": "string",
                    "description": "Source code to review",
                },
                "language": {
                    "type": "string",
                    "description": "Programming language (csharp, python, javascript)",
                    "enum": ["csharp", "python", "javascript", "typescript"],
                },
            },
            "required": ["code", "language"],
        },
        "outputSchema": {
            "type": "object",
            "properties": {
                "findings": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "severity": {"type": "string"},
                            "category": {"type": "string"},
                            "description": {"type": "string"},
                            "line": {"type": "integer"},
                        },
                    },
                },
            },
        },
        "permissions": [
            {"scope": "read:code", "description": "Read source code for analysis"},
        ],
    }

    threat_model_tool = {
        "name": "ssdlc_threat_model",
        "description": "Generate STRIDE threat model for an architecture description",
        "inputSchema": {
            "type": "object",
            "properties": {
                "architecture": {
                    "type": "string",
                    "description": "Architecture description or diagram reference",
                },
                "components": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "List of system components",
                },
            },
            "required": ["architecture"],
        },
        "outputSchema": {
            "type": "object",
            "properties": {
                "threats": {"type": "array"},
                "mitigations": {"type": "array"},
            },
        },
        "permissions": [
            {"scope": "read:architecture", "description": "Read architecture docs"},
        ],
    }

    for name, schema in [
        ("ssdlc_code_review.json", code_review_tool),
        ("ssdlc_threat_model.json", threat_model_tool),
    ]:
        with open(tools_dir / name, "w") as f:
            json.dump(schema, f, indent=2)
        print(f"  Created: {name}")


if __name__ == "__main__":
    schema_result = validate_tool_schemas()
    perm_result = validate_tool_permissions()

    all_passed = (
        schema_result["status"] == "passed"
        and perm_result["status"] in ("passed", "skipped")
    )
    print(f"\n{'=' * 50}")
    print(f"Overall Tool Validation: {'PASSED' if all_passed else 'FAILED'}")
    sys.exit(0 if all_passed else 1)
