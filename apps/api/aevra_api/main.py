from fastapi import FastAPI, Request, status
from fastapi.responses import JSONResponse, PlainTextResponse
from pydantic import BaseModel
from sqlalchemy import text
from starlette.middleware.cors import CORSMiddleware

from aevra_api.api.dependencies import SessionDep, SettingsDep
from aevra_api.api.routes.auth import router as auth_router
from aevra_api.api.routes.brands import router as brands_router
from aevra_api.api.routes.campaigns import router as campaigns_router
from aevra_api.api.routes.knowledge import router as knowledge_router
from aevra_api.api.routes.media import router as media_router
from aevra_api.api.routes.ml import router as ml_router
from aevra_api.api.routes.models import router as models_router
from aevra_api.api.routes.oauth import callback_router as oauth_callback_router
from aevra_api.api.routes.oauth import router as oauth_router
from aevra_api.api.routes.operations import router as operations_router
from aevra_api.api.routes.publishing import router as publishing_router
from aevra_api.api.routes.workspaces import router as workspaces_router
from aevra_api.config import get_settings
from aevra_api.domain.errors import (
    AuthenticationError,
    ConflictError,
    ForbiddenError,
    GenerationError,
    NotFoundError,
    ProviderUnavailableError,
    UnsupportedContentError,
)
from aevra_api.observability import RequestContextMiddleware, metrics


class HealthResponse(BaseModel):
    status: str
    service: str
    phase: int


app = FastAPI(
    title="VAE API",
    version="0.1.0",
    description="Deterministic application boundary for VAE.",
)
app.add_middleware(RequestContextMiddleware)
_cors_origins = [
    origin.strip().rstrip("/")
    for origin in get_settings().allowed_origins.split(",")
    if origin.strip()
]
if _cors_origins:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=_cors_origins,
        allow_credentials=True,
        allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
        allow_headers=["Authorization", "Content-Type", "X-Request-ID"],
    )

app.include_router(auth_router, prefix="/api/v1")
app.include_router(workspaces_router, prefix="/api/v1")
app.include_router(brands_router, prefix="/api/v1")
app.include_router(knowledge_router, prefix="/api/v1")
app.include_router(models_router, prefix="/api/v1")
app.include_router(campaigns_router, prefix="/api/v1")
app.include_router(media_router, prefix="/api/v1")
app.include_router(publishing_router, prefix="/api/v1")
app.include_router(oauth_router, prefix="/api/v1")
app.include_router(oauth_callback_router, prefix="/api/v1")
app.include_router(operations_router, prefix="/api/v1")
app.include_router(ml_router, prefix="/api/v1")


def error_response(code: str, message: str, status_code: int) -> JSONResponse:
    return JSONResponse(
        status_code=status_code,
        content={"error": {"code": code, "message": message}},
    )


@app.exception_handler(AuthenticationError)
def handle_authentication_error(_request: Request, exc: AuthenticationError) -> JSONResponse:
    response = error_response("authentication_failed", str(exc), status.HTTP_401_UNAUTHORIZED)
    response.headers["WWW-Authenticate"] = "Bearer"
    return response


@app.exception_handler(ForbiddenError)
def handle_forbidden_error(_request: Request, exc: ForbiddenError) -> JSONResponse:
    return error_response("forbidden", str(exc), status.HTTP_403_FORBIDDEN)


@app.exception_handler(NotFoundError)
def handle_not_found_error(_request: Request, exc: NotFoundError) -> JSONResponse:
    return error_response("not_found", str(exc), status.HTTP_404_NOT_FOUND)


@app.exception_handler(ConflictError)
def handle_conflict_error(_request: Request, exc: ConflictError) -> JSONResponse:
    return error_response("conflict", str(exc), status.HTTP_409_CONFLICT)


@app.exception_handler(UnsupportedContentError)
def handle_unsupported_content_error(
    _request: Request, exc: UnsupportedContentError
) -> JSONResponse:
    return error_response("unsupported_content", str(exc), status.HTTP_415_UNSUPPORTED_MEDIA_TYPE)


@app.exception_handler(ProviderUnavailableError)
def handle_provider_unavailable_error(
    _request: Request, exc: ProviderUnavailableError
) -> JSONResponse:
    return error_response("provider_unavailable", str(exc), status.HTTP_503_SERVICE_UNAVAILABLE)


@app.exception_handler(GenerationError)
def handle_generation_error(_request: Request, exc: GenerationError) -> JSONResponse:
    return error_response("generation_failed", str(exc), status.HTTP_502_BAD_GATEWAY)


@app.get("/health", response_model=HealthResponse, tags=["system"])
def health() -> HealthResponse:
    return HealthResponse(status="ok", service="aevra-api", phase=12)


@app.get("/ready", tags=["system"])
def readiness(session: SessionDep, settings: SettingsDep) -> JSONResponse:
    """Readiness probe for database and production Redis dependencies."""
    checks: dict[str, str] = {}
    try:
        session.execute(text("SELECT 1"))
        checks["database"] = "ok"
    except Exception:
        checks["database"] = "unavailable"
    if settings.env.lower() in {"staging", "production"} or settings.enable_celery:
        try:
            from redis import Redis  # type: ignore[import-not-found]

            Redis.from_url(settings.redis_url, socket_connect_timeout=2).ping()
            checks["redis"] = "ok"
        except Exception:
            checks["redis"] = "unavailable"
    ready = all(value == "ok" for value in checks.values())
    return JSONResponse(
        status_code=status.HTTP_200_OK if ready else status.HTTP_503_SERVICE_UNAVAILABLE,
        content={"status": "ready" if ready else "not_ready", "checks": checks},
    )


@app.get("/metrics", include_in_schema=False)
def prometheus_metrics() -> PlainTextResponse:
    """A dependency-free Prometheus scrape endpoint for a first monitoring layer."""
    lines = [
        "# HELP aevra_http_requests_total HTTP requests handled",
        "# TYPE aevra_http_requests_total counter",
    ]
    for key, value in sorted(metrics.requests.items()):
        method, path = key.split(" ", 1)
        lines.append(f'aevra_http_requests_total{{method="{method}",path="{path}"}} {value}')
    lines.extend(
        [
            "# HELP aevra_http_failures_total HTTP 5xx responses",
            "# TYPE aevra_http_failures_total counter",
        ]
    )
    for key, value in sorted(metrics.failures.items()):
        method, path = key.split(" ", 1)
        lines.append(f'aevra_http_failures_total{{method="{method}",path="{path}"}} {value}')
    return PlainTextResponse("\n".join(lines) + "\n")
