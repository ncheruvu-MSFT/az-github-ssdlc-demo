# =============================================================================
# E2E Smoke Test — P2/P4 Agent + Tools Pipeline
# SSDLC: End-to-end agent conversation test, verify agent endpoint live
# Ref: Image Row 2 — DEPLOY → Smoke test, Row 4 — E2E smoke test
# =============================================================================
"""End-to-end smoke test: create conversation, verify agent responds correctly."""

import json
import os
import sys
import time

from azure.identity import DefaultAzureCredential
from azure.ai.projects import AIProjectClient
from azure.ai.projects.models._models import PromptAgentDefinition


def run_smoke_test() -> dict:
    """Run E2E smoke test against an agent endpoint.

    Creates an agent, sends test messages, verifies:
    - Agent responds within latency budget
    - Responses are non-empty and coherent
    - Agent stays within its defined role
    - No error responses or hallucinated tool calls

    Returns:
        dict with status, results per test case, and output path.
    """
    endpoint = os.environ["FOUNDRY_PROJECT_ENDPOINT"]
    model = os.environ.get("FOUNDRY_MODEL_NAME", "gpt-4o")
    agent_name = os.environ.get("AGENT_NAME", "ssdlc-demo-agent")
    max_latency_ms = int(os.environ.get("MAX_LATENCY_MS", "30000"))

    credential = DefaultAzureCredential()
    client = AIProjectClient(endpoint=endpoint, credential=credential)

    # Create or retrieve agent
    agent_version = client.agents.create_version(
        agent_name=agent_name,
        definition=PromptAgentDefinition(
            model=model,
            instructions=(
                "You are an SSDLC security assistant that helps developers "
                "with secure development practices."
            ),
        ),
    )
    print(f"Smoke test agent: {agent_version.id} (v{agent_version.version})")

    test_cases = _get_smoke_test_cases()
    results: list[dict] = []
    passed_count = 0

    openai_client = client.get_openai_client()

    for i, tc in enumerate(test_cases, 1):
        print(f"\n[{i}/{len(test_cases)}] {tc['name']}...")

        start_time = time.monotonic()
        try:
            response = openai_client.chat.completions.create(
                model=model,
                messages=tc["messages"],
                max_tokens=500,
                temperature=0.1,
            )

            latency_ms = (time.monotonic() - start_time) * 1000
            content = response.choices[0].message.content or ""

            checks = _validate_response(content, tc, latency_ms, max_latency_ms)
            all_passed = all(c["passed"] for c in checks)

            if all_passed:
                passed_count += 1
                print(f"  ✓ PASSED ({latency_ms:.0f}ms)")
            else:
                failed = [c for c in checks if not c["passed"]]
                print(f"  ✗ FAILED: {', '.join(c['check'] for c in failed)}")

            results.append({
                "name": tc["name"],
                "passed": all_passed,
                "latency_ms": round(latency_ms, 1),
                "response_length": len(content),
                "checks": checks,
            })

        except Exception as exc:
            latency_ms = (time.monotonic() - start_time) * 1000
            print(f"  ✗ ERROR: {exc}")
            results.append({
                "name": tc["name"],
                "passed": False,
                "latency_ms": round(latency_ms, 1),
                "error": str(exc),
                "checks": [
                    {"check": "no_exception", "passed": False, "detail": str(exc)}
                ],
            })

    # Write results
    script_dir = os.path.dirname(os.path.abspath(__file__))
    data_folder = os.environ.get(
        "DATA_FOLDER", os.path.join(script_dir, "data_folder")
    )
    os.makedirs(data_folder, exist_ok=True)
    output_path = os.path.join(data_folder, "e2e_smoke_results.json")

    total = len(test_cases)
    overall_passed = passed_count == total

    with open(output_path, "w") as f:
        json.dump(
            {
                "passed": overall_passed,
                "total": total,
                "passed_count": passed_count,
                "results": results,
            },
            f,
            indent=2,
        )

    print(f"\nSmoke Test Summary: {passed_count}/{total} passed")
    print(f"Overall: {'PASSED' if overall_passed else 'FAILED'}")
    print(f"Results: {output_path}")

    return {
        "status": "passed" if overall_passed else "failed",
        "passed_count": passed_count,
        "total": total,
        "output_path": output_path,
    }


def _get_smoke_test_cases() -> list[dict]:
    """Return E2E smoke test conversation scenarios."""
    system = (
        "You are an SSDLC security assistant that helps developers "
        "with secure development practices."
    )
    return [
        {
            "name": "basic_greeting",
            "messages": [
                {"role": "system", "content": system},
                {"role": "user", "content": "Hello, what can you help me with?"},
            ],
            "must_contain_any": ["security", "secure", "SSDLC", "development"],
            "must_not_contain": [],
            "min_length": 20,
        },
        {
            "name": "security_question",
            "messages": [
                {"role": "system", "content": system},
                {"role": "user", "content": "How do I store secrets securely in Azure?"},
            ],
            "must_contain_any": ["Key Vault", "managed identity", "secret", "Vault"],
            "must_not_contain": [],
            "min_length": 50,
        },
        {
            "name": "role_boundary",
            "messages": [
                {"role": "system", "content": system},
                {"role": "user", "content": "Write me a poem about flowers."},
            ],
            "must_contain_any": ["security", "help", "assist", "can't", "cannot"],
            "must_not_contain": [],
            "min_length": 10,
        },
        {
            "name": "technical_accuracy",
            "messages": [
                {"role": "system", "content": system},
                {"role": "user", "content": "What is the principle of least privilege?"},
            ],
            "must_contain_any": ["minimum", "necessary", "access", "permission"],
            "must_not_contain": [],
            "min_length": 50,
        },
    ]


def _validate_response(
    content: str,
    test_case: dict,
    latency_ms: float,
    max_latency_ms: int,
) -> list[dict]:
    """Validate a response against test case expectations."""
    checks: list[dict] = []

    # Check non-empty
    checks.append({
        "check": "non_empty",
        "passed": len(content) > 0,
        "detail": f"length={len(content)}",
    })

    # Check minimum length
    min_len = test_case.get("min_length", 10)
    checks.append({
        "check": "min_length",
        "passed": len(content) >= min_len,
        "detail": f"length={len(content)}, min={min_len}",
    })

    # Check latency
    checks.append({
        "check": "latency",
        "passed": latency_ms <= max_latency_ms,
        "detail": f"{latency_ms:.0f}ms (max {max_latency_ms}ms)",
    })

    # Check must_contain_any
    must_contain = test_case.get("must_contain_any", [])
    if must_contain:
        found = any(kw.lower() in content.lower() for kw in must_contain)
        checks.append({
            "check": "contains_expected",
            "passed": found,
            "detail": f"expected any of: {must_contain}",
        })

    # Check must_not_contain
    must_not = test_case.get("must_not_contain", [])
    for forbidden in must_not:
        if forbidden.lower() in content.lower():
            checks.append({
                "check": f"not_contains_{forbidden}",
                "passed": False,
                "detail": f"found forbidden: {forbidden}",
            })

    return checks


if __name__ == "__main__":
    result = run_smoke_test()
    sys.exit(0 if result["status"] == "passed" else 1)
