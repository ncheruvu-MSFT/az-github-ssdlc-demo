"""Unit tests for AI Agent module — observability, structure, and safety."""

import importlib
import os
import sys

import pytest

# Ensure src/AIAgent is importable
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "src", "AIAgent"))


class TestObservability:
    """Tests for observability module."""

    def test_get_tracer_returns_tracer(self) -> None:
        import observability

        tracer = observability.get_tracer()
        assert tracer is not None

    def test_setup_tracing_without_connection_string(
        self, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        """Tracing setup should not raise when APPLICATIONINSIGHTS_CONNECTION_STRING is absent."""
        monkeypatch.delenv("APPLICATIONINSIGHTS_CONNECTION_STRING", raising=False)

        # Reset initialization flag
        import observability
        observability._state["initialized"] = False

        # Should not raise
        observability.setup_tracing()

    def test_setup_tracing_idempotent(self) -> None:
        """Calling setup_tracing multiple times should not raise."""
        import observability
        observability._state["initialized"] = False
        observability.setup_tracing()
        observability.setup_tracing()  # Second call should be a no-op


class TestModuleStructure:
    """Tests that all expected modules exist and import cleanly."""

    def test_init_module_imports(self) -> None:
        mod = importlib.import_module("__init__")
        assert mod is not None

    def test_create_agent_module_imports(self) -> None:
        mod = importlib.import_module("create_agent")
        assert hasattr(mod, "create_agent")

    def test_run_agent_module_imports(self) -> None:
        mod = importlib.import_module("run_agent")
        assert hasattr(mod, "run_agent")

    def test_agent_eval_module_imports(self) -> None:
        mod = importlib.import_module("agent_eval")
        assert hasattr(mod, "evaluate_agent")

    def test_red_team_module_imports(self) -> None:
        mod = importlib.import_module("red_team")
        assert hasattr(mod, "red_team_agent")


class TestSafetyChecks:
    """SSDLC: Verify no hardcoded secrets or unsafe patterns in agent code."""

    @pytest.fixture()
    def _agent_source_files(self) -> list[str]:
        """Return paths to all Python source files."""
        src_dir = os.path.join(
            os.path.dirname(__file__), "..", "..", "src", "AIAgent"
        )
        return [
            os.path.join(src_dir, f)
            for f in os.listdir(src_dir)
            if f.endswith(".py")
        ]

    def test_no_hardcoded_keys(self, _agent_source_files: list[str]) -> None:
        """No hardcoded API keys or connection strings in source."""
        forbidden_patterns = [
            "sk-",  # OpenAI key prefix
            "Endpoint=sb://",  # Service Bus connection string
            "AccountKey=",  # Storage account key
            "password=",  # Hardcoded passwords
        ]
        for filepath in _agent_source_files:
            with open(filepath) as f:
                content = f.read()
            for pattern in forbidden_patterns:
                assert pattern not in content, (
                    f"Potential hardcoded secret '{pattern}' found in {filepath}"
                )

    def test_uses_default_azure_credential(
        self, _agent_source_files: list[str]
    ) -> None:
        """Agent scripts should use DefaultAzureCredential for auth."""
        files_with_credential = 0
        for filepath in _agent_source_files:
            with open(filepath) as f:
                content = f.read()
            if "DefaultAzureCredential" in content:
                files_with_credential += 1
        # At least the main agent files should use managed identity
        assert files_with_credential >= 3, (
            "Expected at least 3 files using DefaultAzureCredential"
        )

    def test_no_sensitive_data_in_instructions(self) -> None:
        """Agent instructions should not contain real secrets or endpoints."""
        from create_agent import create_agent

        # Inspect the source code of create_agent for the instructions string
        import inspect

        source = inspect.getsource(create_agent)
        assert "secret" not in source.lower() or "Never reveal" in source
        assert "password" not in source.lower()
