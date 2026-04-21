# =============================================================================
# Agent Evaluation — Azure AI Evaluation SDK
# Metrics: Task Completion, Task Adherence, Intent Resolution,
#          Groundedness, Relevance, Tool Call Accuracy
# SSDLC: Quality gate for AI agent deployments
# =============================================================================
"""Evaluate AI agent quality using Azure AI Evaluation metrics."""

import json
import os
import sys
import time
from pprint import pprint

from azure.identity import DefaultAzureCredential
from azure.ai.projects import AIProjectClient
from openai.types.evals.create_eval_jsonl_run_data_source_param import (
    CreateEvalJSONLRunDataSourceParam,
    SourceFileContent,
    SourceFileContentContent,
)


def evaluate_agent() -> dict:
    """Run evaluation metrics against the SSDLC demo agent.

    Returns:
        dict with evaluation status and report URL.
    """
    endpoint = os.environ["FOUNDRY_PROJECT_ENDPOINT"]
    model = os.environ.get("FOUNDRY_MODEL_NAME", "gpt-4o")

    credential = DefaultAzureCredential()
    client = AIProjectClient(endpoint=endpoint, credential=credential)
    openai_client = client.get_openai_client()

    # Define evaluation schema
    data_source_config = {
        "type": "custom",
        "item_schema": {
            "type": "object",
            "properties": {
                "query": {
                    "anyOf": [
                        {"type": "string"},
                        {"type": "array", "items": {"type": "object"}},
                    ]
                },
                "tool_definitions": {
                    "anyOf": [
                        {"type": "object"},
                        {"type": "array", "items": {"type": "object"}},
                    ]
                },
                "tool_calls": {
                    "anyOf": [
                        {"type": "object"},
                        {"type": "array", "items": {"type": "object"}},
                    ]
                },
                "response": {
                    "anyOf": [
                        {"type": "string"},
                        {"type": "array", "items": {"type": "object"}},
                    ]
                },
            },
            "required": ["query", "response", "tool_definitions"],
        },
        "include_sample_schema": True,
    }

    # Define testing criteria — SSDLC quality metrics
    testing_criteria = [
        # System Evaluation
        {
            "type": "azure_ai_evaluator",
            "name": "task_completion",
            "evaluator_name": "builtin.task_completion",
            "initialization_parameters": {
                "deployment_name": model,
            },
            "data_mapping": {
                "query": "{{item.query}}",
                "response": "{{item.response}}",
                "tool_definitions": "{{item.tool_definitions}}",
            },
        },
        {
            "type": "azure_ai_evaluator",
            "name": "task_adherence",
            "evaluator_name": "builtin.task_adherence",
            "initialization_parameters": {
                "deployment_name": model,
            },
            "data_mapping": {
                "query": "{{item.query}}",
                "response": "{{item.response}}",
                "tool_definitions": "{{item.tool_definitions}}",
            },
        },
        {
            "type": "azure_ai_evaluator",
            "name": "intent_resolution",
            "evaluator_name": "builtin.intent_resolution",
            "initialization_parameters": {
                "deployment_name": model,
            },
            "data_mapping": {
                "query": "{{item.query}}",
                "response": "{{item.response}}",
                "tool_definitions": "{{item.tool_definitions}}",
            },
        },
        # RAG Evaluation
        {
            "type": "azure_ai_evaluator",
            "name": "groundedness",
            "evaluator_name": "builtin.groundedness",
            "initialization_parameters": {
                "deployment_name": model,
            },
            "data_mapping": {
                "query": "{{item.query}}",
                "tool_definitions": "{{item.tool_definitions}}",
                "response": "{{item.response}}",
            },
        },
        {
            "type": "azure_ai_evaluator",
            "name": "relevance",
            "evaluator_name": "builtin.relevance",
            "initialization_parameters": {
                "deployment_name": model,
            },
            "data_mapping": {
                "query": "{{item.query}}",
                "response": "{{item.response}}",
            },
        },
        # Process Evaluation — Tool accuracy
        {
            "type": "azure_ai_evaluator",
            "name": "tool_call_accuracy",
            "evaluator_name": "builtin.tool_call_accuracy",
            "initialization_parameters": {
                "deployment_name": model,
            },
            "data_mapping": {
                "query": "{{item.query}}",
                "tool_definitions": "{{item.tool_definitions}}",
                "tool_calls": "{{item.tool_calls}}",
                "response": "{{item.response}}",
            },
        },
    ]

    print("Creating evaluation group...")
    eval_obj = openai_client.evals.create(
        name="ssdlc_agent_eval",
        data_source_config=data_source_config,
        testing_criteria=testing_criteria,
    )
    print(f"Eval group created: {eval_obj.id}")

    # Sample test data — SSDLC-themed queries
    query = [
        {"role": "system", "content": "You are an SSDLC security assistant."},
        {
            "role": "user",
            "content": [
                {
                    "type": "text",
                    "text": "What container security scanning tools should I use in my CI pipeline?",
                }
            ],
        },
    ]

    response = [
        {
            "role": "assistant",
            "content": [
                {
                    "type": "text",
                    "text": (
                        "For container security scanning in CI pipelines, I recommend: "
                        "1) Microsoft Defender for Containers — integrated with GitHub Actions "
                        "via microsoft/security-devops-action. "
                        "2) Notation (Notary v2) for container image signing to verify integrity. "
                        "3) Dependabot or Renovate for dependency vulnerability scanning. "
                        "Always scan before pushing to ACR and verify signatures before deployment."
                    ),
                }
            ],
        },
    ]

    tool_definitions = [
        {
            "name": "search_docs",
            "description": "Search Microsoft security documentation.",
            "parameters": {
                "type": "object",
                "properties": {
                    "query": {
                        "type": "string",
                        "description": "Search query for docs.",
                    }
                },
            },
        },
    ]

    print("Creating evaluation run with inline data...")
    eval_run = openai_client.evals.runs.create(
        eval_id=eval_obj.id,
        name="ssdlc_eval_run",
        metadata={"team": "SSDLC", "scenario": "container-security"},
        data_source=CreateEvalJSONLRunDataSourceParam(
            type="jsonl",
            source=SourceFileContent(
                type="file_content",
                content=[
                    SourceFileContentContent(
                        item={
                            "query": query,
                            "tool_definitions": tool_definitions,
                            "response": response,
                            "tool_calls": None,
                        }
                    ),
                ],
            ),
        ),
    )

    print(f"Eval run created: {eval_run.id}")

    # Poll for completion
    while True:
        run = openai_client.evals.runs.retrieve(
            run_id=eval_run.id, eval_id=eval_obj.id
        )
        if run.status in ("completed", "failed"):
            output_items = list(
                openai_client.evals.runs.output_items.list(
                    run_id=run.id, eval_id=eval_obj.id
                )
            )
            print(f"\nEval run status: {run.status}")
            print(f"Report URL: {run.report_url}")
            pprint(output_items)
            return {
                "status": run.status,
                "report_url": run.report_url,
                "eval_id": eval_obj.id,
                "run_id": run.id,
            }
        time.sleep(5)
        print(f"Waiting for eval run... status={run.status}")


if __name__ == "__main__":
    result = evaluate_agent()
    print(f"\nEvaluation complete: {result['status']}")
    sys.exit(0 if result["status"] == "completed" else 1)
