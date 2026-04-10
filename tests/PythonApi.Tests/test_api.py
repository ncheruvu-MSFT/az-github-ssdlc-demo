"""
Python API Tests — unit + integration tests for FastAPI endpoints.
"""

import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app


@pytest.fixture
def client():
    """Synchronous test client."""
    from fastapi.testclient import TestClient

    return TestClient(app)


@pytest.fixture
async def async_client():
    """Async test client for async endpoint tests."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


class TestRootEndpoint:
    def test_root_returns_ok(self, client):
        response = client.get("/")
        assert response.status_code == 200

    def test_root_contains_service_name(self, client):
        response = client.get("/")
        data = response.json()
        assert "service" in data
        assert "Python Hello World API" in data["service"]

    def test_root_contains_timestamp(self, client):
        response = client.get("/")
        data = response.json()
        assert "timestamp" in data


class TestHelloEndpoint:
    def test_hello_without_name(self, client):
        response = client.get("/api/hello")
        assert response.status_code == 200
        data = response.json()
        assert data["message"] == "Hello, World!"

    def test_hello_with_name(self, client):
        response = client.get("/api/hello?name=Azure")
        assert response.status_code == 200
        data = response.json()
        assert data["message"] == "Hello, Azure!"

    def test_hello_returns_version(self, client):
        response = client.get("/api/hello")
        data = response.json()
        assert data["version"] == "1.0.0"

    def test_hello_returns_timestamp(self, client):
        response = client.get("/api/hello")
        data = response.json()
        assert "timestamp" in data

    def test_hello_response_model(self, client):
        response = client.get("/api/hello")
        data = response.json()
        assert set(data.keys()) == {"message", "timestamp", "version"}


class TestHealthEndpoint:
    def test_health_returns_ok(self, client):
        response = client.get("/health")
        assert response.status_code == 200

    def test_health_returns_healthy(self, client):
        response = client.get("/health")
        data = response.json()
        assert data["status"] == "Healthy"


class TestInfoEndpoint:
    def test_info_returns_ok(self, client):
        response = client.get("/api/info")
        assert response.status_code == 200

    def test_info_contains_python_version(self, client):
        response = client.get("/api/info")
        data = response.json()
        assert "python_version" in data

    def test_info_contains_environment(self, client):
        response = client.get("/api/info")
        data = response.json()
        assert "environment" in data


class TestEchoEndpoint:
    def test_echo_returns_posted_body(self, client):
        payload = {"key": "value", "number": 42}
        response = client.post("/api/echo", json=payload)
        assert response.status_code == 200
        data = response.json()
        assert data["echo"] == payload

    def test_echo_with_invalid_json(self, client):
        response = client.post(
            "/api/echo", content="not json", headers={"Content-Type": "application/json"}
        )
        assert response.status_code == 400

    def test_echo_contains_timestamp(self, client):
        response = client.post("/api/echo", json={"test": True})
        data = response.json()
        assert "timestamp" in data


class TestSecurityHeaders:
    def test_cors_headers_not_exposed_without_origin(self, client):
        response = client.get("/api/hello")
        # Without Origin header, CORS headers should not be present
        assert "access-control-allow-origin" not in response.headers


class TestAsyncEndpoints:
    @pytest.mark.asyncio
    async def test_hello_async(self, async_client):
        response = await async_client.get("/api/hello?name=Async")
        assert response.status_code == 200
        assert response.json()["message"] == "Hello, Async!"

    @pytest.mark.asyncio
    async def test_health_async(self, async_client):
        response = await async_client.get("/health")
        assert response.status_code == 200
