# =============================================================================
# Policy Validation — P3 Agent + FoundryIQ Model Pipeline
# SSDLC: FoundryIQ policy rules, model routing validation, schema lint
# Ref: Image Row 3 — BUILD (Job 1) + EVALUATE (Job 2: AI-powered)
# =============================================================================
"""Validate FoundryIQ routing policies, model routing rules, and cost estimates."""

import json
import os
import sys
from pathlib import Path


def validate_policies() -> dict:
    """Validate FoundryIQ policy configuration files.

    Checks:
    - Policy JSON schema validity
    - Model routing rules are well-formed
    - Fallback routes defined for every primary route
    - Cost-per-query budgets within limits
    - No duplicate route priorities

    Returns:
        dict with status, errors, and warnings.
    """
    script_dir = Path(os.path.dirname(os.path.abspath(__file__)))
    config_dir = script_dir / "config"

    errors: list[str] = []
    warnings: list[str] = []

    # Check for policy config files
    policy_file = config_dir / "foundryiq_policy.json"
    routing_file = config_dir / "model_routing.json"

    if not config_dir.exists():
        print(f"Config directory not found: {config_dir}")
        print("Creating default config templates...")
        config_dir.mkdir(parents=True, exist_ok=True)
        _create_default_policy(policy_file)
        _create_default_routing(routing_file)

    # Validate policy file
    if policy_file.exists():
        print("Validating FoundryIQ policy config...")
        policy_errors = _validate_policy_file(policy_file)
        errors.extend(policy_errors)
    else:
        errors.append(f"Missing policy file: {policy_file}")

    # Validate routing config
    if routing_file.exists():
        print("Validating model routing config...")
        routing_errors, routing_warnings = _validate_routing_file(routing_file)
        errors.extend(routing_errors)
        warnings.extend(routing_warnings)
    else:
        errors.append(f"Missing routing file: {routing_file}")

    # Validate routing schema lint
    schema_warnings = _lint_config_schemas(config_dir)
    warnings.extend(schema_warnings)

    passed = len(errors) == 0

    print("\nPolicy Validation Results:")
    print(f"  Errors: {len(errors)}")
    print(f"  Warnings: {len(warnings)}")
    print(f"  Overall: {'PASSED' if passed else 'FAILED'}")

    for e in errors:
        print(f"  ✗ ERROR: {e}")
    for w in warnings:
        print(f"  ⚠ WARN: {w}")

    return {
        "status": "passed" if passed else "failed",
        "errors": errors,
        "warnings": warnings,
    }


def validate_multi_model_eval_config() -> dict:
    """Validate multi-model evaluation configuration.

    Ref: Image Row 3 — EVALUATE (Multi-Model Eval)
    Checks that each model has defined:
    - Primary route & fallback route
    - Content safety thresholds per model
    - Cost-per-query budget
    - Response quality expectations

    Returns:
        dict with status, model configs, and any issues.
    """
    script_dir = Path(os.path.dirname(os.path.abspath(__file__)))
    routing_file = script_dir / "config" / "model_routing.json"

    if not routing_file.exists():
        return {
            "status": "skipped",
            "reason": "No model routing config found",
        }

    with open(routing_file) as f:
        config = json.load(f)

    models = config.get("models", [])
    issues: list[str] = []
    model_configs: list[dict] = []

    for model_cfg in models:
        name = model_cfg.get("name", "unnamed")
        required_fields = [
            "name",
            "endpoint",
            "max_cost_per_query",
            "safety_threshold",
        ]
        missing = [
            field for field in required_fields if field not in model_cfg
        ]
        if missing:
            issues.append(f"Model '{name}' missing fields: {missing}")

        # Check fallback
        if not model_cfg.get("fallback_model"):
            issues.append(f"Model '{name}' has no fallback model defined")

        model_configs.append({
            "name": name,
            "has_fallback": bool(model_cfg.get("fallback_model")),
            "cost_budget": model_cfg.get("max_cost_per_query"),
            "safety_threshold": model_cfg.get("safety_threshold"),
        })

    passed = len(issues) == 0
    print("\nMulti-Model Config Validation:")
    print(f"  Models: {len(models)}")
    print(f"  Issues: {len(issues)}")
    print(f"  Overall: {'PASSED' if passed else 'FAILED'}")

    return {
        "status": "passed" if passed else "failed",
        "model_configs": model_configs,
        "issues": issues,
    }


def _validate_policy_file(path: Path) -> list[str]:
    """Validate FoundryIQ policy JSON structure."""
    errors: list[str] = []
    try:
        with open(path) as f:
            policy = json.load(f)
    except json.JSONDecodeError as exc:
        return [f"Invalid JSON in {path}: {exc}"]

    required_keys = ["version", "rules"]
    for key in required_keys:
        if key not in policy:
            errors.append(f"Policy missing required key: '{key}'")

    # Validate rules
    rules = policy.get("rules", [])
    if not rules:
        errors.append("Policy has no rules defined")

    seen_priorities: set[int] = set()
    for i, rule in enumerate(rules):
        rule_name = rule.get("name", f"rule[{i}]")

        if "action" not in rule:
            errors.append(f"Rule '{rule_name}' missing 'action'")
        if "condition" not in rule:
            errors.append(f"Rule '{rule_name}' missing 'condition'")

        priority = rule.get("priority")
        if priority is not None:
            if priority in seen_priorities:
                errors.append(
                    f"Duplicate priority {priority} in rule '{rule_name}'"
                )
            seen_priorities.add(priority)

        # Check for valid actions
        valid_actions = ["allow", "block", "route", "rate_limit", "log"]
        action = rule.get("action")
        if action and action not in valid_actions:
            errors.append(
                f"Rule '{rule_name}' has invalid action: '{action}' "
                f"(valid: {valid_actions})"
            )

    return errors


def _validate_routing_file(path: Path) -> tuple[list[str], list[str]]:
    """Validate model routing configuration."""
    errors: list[str] = []
    warnings: list[str] = []

    try:
        with open(path) as f:
            config = json.load(f)
    except json.JSONDecodeError as exc:
        return [f"Invalid JSON in {path}: {exc}"], []

    models = config.get("models", [])
    if not models:
        errors.append("No models defined in routing config")

    model_names = set()
    for model in models:
        name = model.get("name")
        if not name:
            errors.append("Model entry missing 'name'")
            continue

        if name in model_names:
            errors.append(f"Duplicate model name: '{name}'")
        model_names.add(name)

        max_cost = model.get("max_cost_per_query")
        if max_cost is not None and max_cost <= 0:
            errors.append(f"Model '{name}' has invalid cost budget: {max_cost}")

        safety = model.get("safety_threshold")
        if safety is not None and not (0 <= safety <= 1):
            warnings.append(
                f"Model '{name}' safety_threshold={safety} outside [0,1]"
            )

    # Check fallback references
    for model in models:
        fallback = model.get("fallback_model")
        if fallback and fallback not in model_names:
            errors.append(
                f"Model '{model.get('name')}' references unknown fallback: '{fallback}'"
            )

    return errors, warnings


def _lint_config_schemas(config_dir: Path) -> list[str]:
    """Lint all JSON config files in the config directory."""
    warnings: list[str] = []
    for json_file in config_dir.glob("*.json"):
        try:
            with open(json_file) as f:
                data = json.load(f)
            if not isinstance(data, dict):
                warnings.append(f"{json_file.name}: root is not an object")
        except json.JSONDecodeError as exc:
            warnings.append(f"{json_file.name}: parse error: {exc}")
    return warnings


def _create_default_policy(path: Path) -> None:
    """Create a default FoundryIQ policy config."""
    policy = {
        "version": "1.0",
        "description": "SSDLC Demo — FoundryIQ Policy Rules",
        "rules": [
            {
                "name": "block_prohibited_content",
                "priority": 1,
                "condition": "content_safety_score >= 0.7",
                "action": "block",
                "description": "Block responses with high safety risk scores",
            },
            {
                "name": "rate_limit_per_user",
                "priority": 2,
                "condition": "requests_per_minute > 60",
                "action": "rate_limit",
                "description": "Rate limit to prevent denial-of-wallet",
            },
            {
                "name": "route_to_fallback",
                "priority": 3,
                "condition": "primary_model_latency > 5000",
                "action": "route",
                "description": "Route to fallback model on high latency",
            },
            {
                "name": "log_all_requests",
                "priority": 100,
                "condition": "true",
                "action": "log",
                "description": "Log all requests for audit trail",
            },
        ],
    }
    with open(path, "w") as f:
        json.dump(policy, f, indent=2)
    print(f"  Created default policy: {path}")


def _create_default_routing(path: Path) -> None:
    """Create a default model routing config."""
    routing = {
        "version": "1.0",
        "description": "SSDLC Demo — Multi-Model Routing Configuration",
        "models": [
            {
                "name": "gpt-4o",
                "endpoint": "env:FOUNDRY_PROJECT_ENDPOINT",
                "max_cost_per_query": 0.05,
                "safety_threshold": 0.8,
                "fallback_model": "gpt-4o-mini",
                "use_for": ["complex_analysis", "security_review"],
            },
            {
                "name": "gpt-4o-mini",
                "endpoint": "env:FOUNDRY_PROJECT_ENDPOINT",
                "max_cost_per_query": 0.01,
                "safety_threshold": 0.8,
                "fallback_model": "gpt-4o",
                "use_for": ["simple_queries", "classification"],
            },
        ],
    }
    with open(path, "w") as f:
        json.dump(routing, f, indent=2)
    print(f"  Created default routing: {path}")


if __name__ == "__main__":
    # Run both validations
    policy_result = validate_policies()
    model_result = validate_multi_model_eval_config()

    all_passed = (
        policy_result["status"] == "passed"
        and model_result["status"] in ("passed", "skipped")
    )
    print(f"\n{'=' * 50}")
    print(f"Overall Policy Validation: {'PASSED' if all_passed else 'FAILED'}")
    sys.exit(0 if all_passed else 1)
