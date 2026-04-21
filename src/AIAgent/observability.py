# =============================================================================
# Observability — OpenTelemetry tracing for AI Agent operations
# SSDLC: Full trace correlation across agent lifecycle
# =============================================================================
"""OpenTelemetry setup for AI Agent tracing and monitoring."""

import os

from azure.monitor.opentelemetry import configure_azure_monitor
from opentelemetry import trace


_initialized = False


def setup_tracing() -> None:
    """Configure OpenTelemetry with Azure Monitor (Application Insights).

    Safe to call multiple times — only initializes once.
    """
    global _initialized
    if _initialized:
        return

    conn_string = os.environ.get("APPLICATIONINSIGHTS_CONNECTION_STRING")
    if conn_string:
        configure_azure_monitor(connection_string=conn_string)
        print("OpenTelemetry tracing enabled (Azure Monitor)")
    else:
        print("APPLICATIONINSIGHTS_CONNECTION_STRING not set — tracing disabled")

    _initialized = True


def get_tracer() -> trace.Tracer:
    """Return the OpenTelemetry tracer for the AI Agent module."""
    return trace.get_tracer("ssdlc-ai-agent")
