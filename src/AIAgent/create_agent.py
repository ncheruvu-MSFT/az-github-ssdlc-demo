# =============================================================================
# Create Agent — Azure AI Foundry Agent Deployment
# SSDLC: Managed Identity auth, OpenTelemetry tracing, no hardcoded secrets
# =============================================================================
"""Create and deploy an AI agent to Azure AI Foundry."""

import os
import sys

from azure.identity import DefaultAzureCredential
from azure.ai.projects import AIProjectClient
from azure.ai.projects.models._models import PromptAgentDefinition
from opentelemetry.trace import SpanKind
from opentelemetry.trace.span import format_trace_id

from observability import setup_tracing, get_tracer


def create_agent() -> dict[str, str]:
    """Create an AI agent version in Azure AI Foundry.

    Returns:
        dict with agent name, id, and version.
    """
    setup_tracing()

    endpoint = os.environ["FOUNDRY_PROJECT_ENDPOINT"]
    if not endpoint.startswith("https://"):
        raise ValueError(
            "FOUNDRY_PROJECT_ENDPOINT must use HTTPS. "
            f"Got: {endpoint[:20]}..."
        )
    agent_name = os.environ.get("AGENT_NAME", "ssdlc-demo-agent")
    model = os.environ.get("FOUNDRY_MODEL_NAME", "gpt-4o")

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

        # Create agent version with SSDLC-focused instructions
        agent_version = client.agents.create_version(
            agent_name=agent_name,
            definition=PromptAgentDefinition(
                model=model,
                instructions=(
                    "You are an SSDLC Demo Agent — an AI assistant that helps "
                    "developers understand secure software development lifecycle "
                    "practices. You can answer questions about CI/CD security, "
                    "container signing, dependency scanning, and Azure deployment "
                    "best practices. Always cite official Microsoft documentation "
                    "when possible. Never reveal internal credentials or secrets."
                ),
            ),
        )

        print(
            f"Agent created: name={agent_version.name}, "
            f"id={agent_version.id}, version={agent_version.version}"
        )
        span.set_attribute("agent.name", agent_version.name)
        span.set_attribute("agent.id", agent_version.id)

        return {
            "name": agent_version.name,
            "id": agent_version.id,
            "version": agent_version.version,
        }


if __name__ == "__main__":
    result = create_agent()
    print(f"Result: {result}")
    sys.exit(0)
