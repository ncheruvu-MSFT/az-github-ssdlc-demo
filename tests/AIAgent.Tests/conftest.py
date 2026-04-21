"""Fixtures for AI Agent tests."""

import os
import sys

import pytest

# Add src/AIAgent to path so modules can be imported
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "src", "AIAgent"))


@pytest.fixture(autouse=True)
def _set_env_vars(monkeypatch: pytest.MonkeyPatch) -> None:
    """Set required environment variables for all tests."""
    monkeypatch.setenv("FOUNDRY_PROJECT_ENDPOINT", "https://test.services.ai.azure.com/api/projects/test")
    monkeypatch.setenv("FOUNDRY_MODEL_NAME", "gpt-4o")
    monkeypatch.setenv("AGENT_NAME", "test-agent")
