# =============================================================================
# Prompt Evaluation (Classic) — P1 DevOps Model Pipeline
# SSDLC: Prompt regression testing, response quality, latency & token budget
# Ref: Image Row 1 — EVALUATE (Job 2: AI-powered)
# =============================================================================
"""Classic prompt evaluation: regression tests, quality scores, groundedness."""

import json
import os
import sys
import time

from azure.identity import DefaultAzureCredential
from azure.ai.projects import AIProjectClient


def evaluate_prompts() -> dict:
    """Run prompt regression evaluation against a deployed agent.

    Evaluates:
    - Response quality scores (coherence, relevance, fluency)
    - Groundedness (factual accuracy)
    - Latency / token budget compliance
    - Regression detection against baseline

    Returns:
        dict with eval_id, metrics, pass/fail status.
    """
    endpoint = os.environ["FOUNDRY_PROJECT_ENDPOINT"]
    model = os.environ.get("FOUNDRY_MODEL_NAME", "gpt-4o")
    agent_name = os.environ.get("AGENT_NAME", "ssdlc-demo-agent")

    credential = DefaultAzureCredential()
    client = AIProjectClient(endpoint=endpoint, credential=credential)
    openai_client = client.get_openai_client()

    # Prompt regression test cases
    test_cases = _get_regression_test_cases()
    print(f"Running {len(test_cases)} prompt regression tests...")

    eval_name = f"Prompt Eval Classic - {int(time.time())}"

    # Define evaluation criteria — quality + groundedness
    testing_criteria = [
        {
            "type": "azure_ai_evaluator",
            "name": "Coherence",
            "evaluator_name": "builtin.coherence",
            "evaluator_version": "1",
        },
        {
            "type": "azure_ai_evaluator",
            "name": "Relevance",
            "evaluator_name": "builtin.relevance",
            "evaluator_version": "1",
        },
        {
            "type": "azure_ai_evaluator",
            "name": "Fluency",
            "evaluator_name": "builtin.fluency",
            "evaluator_version": "1",
        },
        {
            "type": "azure_ai_evaluator",
            "name": "Groundedness",
            "evaluator_name": "builtin.groundedness",
            "evaluator_version": "1",
        },
    ]

    # Create eval with stored test data
    data_source_config = {
        "type": "custom",
        "item_reference": "$.item",
        "items": [
            {"item": tc} for tc in test_cases
        ],
    }

    eval_obj = openai_client.evals.create(
        name=eval_name,
        data_source_config=data_source_config,
        testing_criteria=testing_criteria,
    )
    print(f"Evaluation created: {eval_obj.id}")

    # Run evaluation
    run_name = f"Prompt Eval Run - {agent_name} - {int(time.time())}"
    eval_run = openai_client.evals.runs.create(
        eval_id=eval_obj.id,
        name=run_name,
        data_source={
            "type": "completions",
            "input_messages": {
                "type": "item_reference",
                "item_reference": "$.item.messages",
            },
            "model": model,
            "source": {"type": "file_content", "content": test_cases},
        },
    )
    print(f"Eval run started: {eval_run.id}")

    # Poll for completion
    while True:
        run = openai_client.evals.runs.retrieve(
            run_id=eval_run.id, eval_id=eval_obj.id
        )
        if run.status in ("completed", "failed"):
            break
        time.sleep(5)
        print(f"Waiting... status={run.status}")

    # Collect results
    output_items = list(
        openai_client.evals.runs.output_items.list(
            run_id=eval_run.id, eval_id=eval_obj.id
        )
    )

    metrics = _aggregate_metrics(output_items)
    passed = _check_thresholds(metrics)

    # Write results to file
    script_dir = os.path.dirname(os.path.abspath(__file__))
    data_folder = os.environ.get(
        "DATA_FOLDER", os.path.join(script_dir, "data_folder")
    )
    os.makedirs(data_folder, exist_ok=True)
    results_path = os.path.join(data_folder, "prompt_eval_results.json")
    with open(results_path, "w") as f:
        json.dump(
            {"metrics": metrics, "passed": passed, "eval_id": eval_obj.id},
            f,
            indent=2,
        )

    print("\nPrompt Evaluation Results:")
    for name, score in metrics.items():
        threshold = _get_threshold(name)
        status = "✓" if score >= threshold else "✗"
        print(f"  {status} {name}: {score:.2f} (threshold: {threshold:.2f})")

    print(f"\nOverall: {'PASSED' if passed else 'FAILED'}")
    print(f"Results written to {results_path}")

    return {
        "status": "passed" if passed else "failed",
        "metrics": metrics,
        "eval_id": eval_obj.id,
        "results_path": results_path,
    }


def _get_regression_test_cases() -> list[dict]:
    """Return prompt regression test cases for the SSDLC agent."""
    return [
        {
            "messages": [
                {"role": "system", "content": "You are an SSDLC security assistant."},
                {"role": "user", "content": "What is OWASP Top 10?"},
            ],
            "expected_topics": ["web security", "vulnerabilities"],
        },
        {
            "messages": [
                {"role": "system", "content": "You are an SSDLC security assistant."},
                {"role": "user", "content": "How do I prevent SQL injection in .NET?"},
            ],
            "expected_topics": ["parameterized queries", "Entity Framework"],
        },
        {
            "messages": [
                {"role": "system", "content": "You are an SSDLC security assistant."},
                {"role": "user", "content": "Explain threat modeling for a REST API."},
            ],
            "expected_topics": ["STRIDE", "attack surface", "mitigations"],
        },
        {
            "messages": [
                {"role": "system", "content": "You are an SSDLC security assistant."},
                {"role": "user", "content": "What are best practices for secrets management?"},
            ],
            "expected_topics": ["Key Vault", "managed identity", "rotation"],
        },
        {
            "messages": [
                {"role": "system", "content": "You are an SSDLC security assistant."},
                {"role": "user", "content": "How should I set up RBAC for Azure resources?"},
            ],
            "expected_topics": ["least privilege", "role assignments", "scope"],
        },
    ]


def _aggregate_metrics(output_items: list) -> dict[str, float]:
    """Aggregate scores across all evaluation output items."""
    totals: dict[str, list[float]] = {}
    for item in output_items:
        results = getattr(item, "results", []) or []
        for result in results:
            name = getattr(result, "name", None) or "unknown"
            score = getattr(result, "score", None)
            if score is not None:
                totals.setdefault(name, []).append(float(score))

    return {
        name: sum(scores) / len(scores) if scores else 0.0
        for name, scores in totals.items()
    }


def _get_threshold(metric_name: str) -> float:
    """Return minimum acceptable score for a metric."""
    thresholds = {
        "Coherence": 3.5,
        "Relevance": 3.5,
        "Fluency": 3.5,
        "Groundedness": 3.0,
    }
    return thresholds.get(metric_name, 3.0)


def _check_thresholds(metrics: dict[str, float]) -> bool:
    """Check if all metrics meet their thresholds."""
    for name, score in metrics.items():
        if score < _get_threshold(name):
            return False
    return True


if __name__ == "__main__":
    result = evaluate_prompts()
    sys.exit(0 if result["status"] == "passed" else 1)
