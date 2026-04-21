# =============================================================================
# Run Agent — Query an existing Azure AI Foundry agent
# SSDLC: Managed Identity auth, structured output, tracing
# =============================================================================
"""Test an existing AI agent by sending queries and validating responses."""

import os
import sys
import time

from azure.identity import DefaultAzureCredential
from azure.ai.projects import AIProjectClient
from opentelemetry.trace import SpanKind
from opentelemetry.trace.span import format_trace_id

from observability import setup_tracing, get_tracer


def run_agent(query: str | None = None) -> str | None:
    """Query an existing AI agent and return the response text.

    Args:
        query: The question to send to the agent. Uses default if None.

    Returns:
        The agent's text response, or None on failure.
    """
    setup_tracing()

    endpoint = os.environ["FOUNDRY_PROJECT_ENDPOINT"]
    agent_name = os.environ.get("AGENT_NAME", "ssdlc-demo-agent")
    model = os.environ.get("FOUNDRY_MODEL_NAME", "gpt-4o")

    if query is None:
        query = "What are the top 3 OWASP security practices for CI/CD pipelines?"

    with get_tracer().start_as_current_span(
        "RunSSDLCAgent", kind=SpanKind.CLIENT
    ) as span:
        trace_id = format_trace_id(span.get_span_context().trace_id)
        print(f"Trace ID: {trace_id}")

        credential = DefaultAzureCredential()
        client = AIProjectClient(endpoint=endpoint, credential=credential)
        openai_client = client.get_openai_client()

        print(f"Querying agent: {agent_name}")
        span.set_attribute("agent.name", agent_name)

        # Send query using agent_reference (SDK v2.0+)
        response = openai_client.responses.create(
            model=model,
            input=[{"role": "user", "content": query}],
            extra_body={
                "agent_reference": {
                    "name": agent_name,
                    "type": "agent_reference",
                }
            },
        )

        print(f"Response status: {response.status}, id: {response.id}")

        # Handle MCP approval requests if present
        mcp_requests = [
            item for item in response.output
            if getattr(item, "type", None) == "mcp_approval_request"
        ]

        if mcp_requests:
            print(f"Auto-approving {len(mcp_requests)} MCP tool call(s)...")
            for req in mcp_requests:
                response = openai_client.responses.create(
                    previous_response_id=response.id,
                    input=[{
                        "type": "mcp_approval_response",
                        "approve": True,
                        "approval_request_id": req.id,
                    }],
                    extra_body={
                        "agent_reference": {
                            "name": agent_name,
                            "type": "agent_reference",
                        }
                    },
                )

            # Poll for completion
            for _ in range(30):
                response = openai_client.responses.retrieve(
                    response_id=response.id
                )
                if response.status in ("completed", "failed"):
                    break
                time.sleep(2)

        # Extract text response
        response_text = _extract_text(response)
        if response_text:
            print(f"\nAgent response:\n{response_text}")
        else:
            print("No text response received")

        span.set_attribute("response.length", len(response_text or ""))
        return response_text


def _extract_text(response: object) -> str | None:
    """Extract text content from agent response."""
    for item in response.output:
        item_type = getattr(item, "type", None)
        if item_type == "message" and hasattr(item, "content"):
            for content in item.content:
                if hasattr(content, "text"):
                    return content.text
        elif item_type == "response_output_text":
            return item.text
    return None


if __name__ == "__main__":
    result = run_agent()
    sys.exit(0 if result else 1)
