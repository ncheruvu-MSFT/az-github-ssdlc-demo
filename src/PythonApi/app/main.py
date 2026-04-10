"""
Python Hello World API — FastAPI enterprise pattern.
Deployed to Azure Container Apps.
"""

import os
from datetime import datetime, timezone

from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel

app = FastAPI(
    title="Python Hello World API",
    description="Enterprise Python API deployed on Azure Container Apps",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

# CORS — restrictive by default
app.add_middleware(
    CORSMiddleware,
    allow_origins=[os.getenv("ALLOWED_ORIGINS", "https://portal.azure.com")],
    allow_credentials=False,
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
    max_age=3600,
)


# ── Models ────────────────────────────────────────────────────────
class HelloResponse(BaseModel):
    message: str
    timestamp: str
    version: str


class HealthResponse(BaseModel):
    status: str
    timestamp: str


class InfoResponse(BaseModel):
    service: str
    environment: str
    python_version: str
    timestamp: str


# ── Error handling ────────────────────────────────────────────────
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    return JSONResponse(
        status_code=500,
        content={"error": "Internal server error", "timestamp": datetime.now(timezone.utc).isoformat()},
    )


# ── Endpoints ─────────────────────────────────────────────────────
@app.get("/", response_model=dict)
async def root():
    return {
        "service": "Python Hello World API",
        "status": "Running",
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


@app.get("/api/hello", response_model=HelloResponse)
async def hello(name: str | None = None):
    greeting = name if name else "World"
    return HelloResponse(
        message=f"Hello, {greeting}!",
        timestamp=datetime.now(timezone.utc).isoformat(),
        version="1.0.0",
    )


@app.get("/health", response_model=HealthResponse)
async def health():
    return HealthResponse(
        status="Healthy",
        timestamp=datetime.now(timezone.utc).isoformat(),
    )


@app.get("/api/info", response_model=InfoResponse)
async def info():
    import platform

    return InfoResponse(
        service="Python Hello World API",
        environment=os.getenv("ENVIRONMENT", "development"),
        python_version=platform.python_version(),
        timestamp=datetime.now(timezone.utc).isoformat(),
    )


@app.post("/api/echo")
async def echo(request: Request):
    """Echo endpoint for testing — returns posted JSON body."""
    try:
        body = await request.json()
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid JSON body")
    return {"echo": body, "timestamp": datetime.now(timezone.utc).isoformat()}
