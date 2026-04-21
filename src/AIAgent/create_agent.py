# =============================================================================
# Create Agent — Azure AI Foundry Agent Deployment
# SSDLC: Managed Identity auth, OpenTelemetry tracing, no hardcoded secrets
# =============================================================================
"""Create and deploy an AI agent to Azure AI Foundry."""

import asyncio
import os
import sys

from azure.identity import DefaultAzureCredential
from azure.ai.projects import AIProjectClient
from opentelemetry.trace import SpanKind
from opentelemetry.trace.span import format_trace_id

from observability import setup_tracing, get_tracer


def create_agent() -> dict[str, str]:
    """Create an AI agent in Azure AI Foundry.

    Returns:
        dict with agent name and id.
    """
    setup_tracing()

    endpoint = os.environ["AZURE_AI_PROJECT"]
    agent_name = os.environ.get("AGENT_NAME", "ssdlc-demo-agent")
    model = os.environ.get("AZURE_AI_MODEL_DEPLOYMENT_NAME", "gpt-4o")

    with get_tracer().start_as_current_span(
        "CreateSSDLCAgent", kind=SpanKind.CLIENT
    ) as span:
        trace_id = format_trace_id(span.get_span_context().trace_id)
        print(f"Trace ID: {trace_id}")

        credential = DefaultAzureCredential()
        client = AIProjectClient(
            endpoint=endpoint,
            credential=credential,
        )

        # Create agent with SSDLC-focused instructions
        agent = client.agents.create_agent(
            model=model,
            name=agent_name,
            instructions=(
                "You are an SSDLC Demo Agent — an AI assistant that helps "
                "developers understand secure software development lifecycle "
                "practices. You can answer questions about CI/CD security, "
                "container signing, dependency scanning, and Azure deployment "
                "best practices. Always cite official Microsoft documentation "
                "when possible. Never reveal internal credentials or secrets."
            ),
        )

        print(f"Agent created: name={agent.name}, id={agent.id}")
        span.set_attribute("agent.name", agent.name)
        span.set_attribute("agent.id", agent.id)

        return {"name": agent.name, "id": agent.id}


if __name__ == "__main__":
    result = create_agent()
    print(f"Result: {result}")
    sys.exit(0)
