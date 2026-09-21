import uuid

from fastapi import APIRouter, status

from aevra_api.api.dependencies import CurrentUser, SessionDep, SettingsDep
from aevra_api.schemas.operations import (
    AuditLogResponse,
    MetricsCreateRequest,
    MetricsResponse,
    ScheduleCreateRequest,
    ScheduledPostResponse,
    ScheduleRescheduleRequest,
)
from aevra_api.services.analytics_polling import AnalyticsPoller
from aevra_api.services.operations import OperationsService

router = APIRouter(prefix="/workspaces/{workspace_id}/operations", tags=["operations"])


@router.post("/schedule", response_model=ScheduledPostResponse, status_code=status.HTTP_201_CREATED)
def schedule(
    workspace_id: uuid.UUID,
    request: ScheduleCreateRequest,
    current_user: CurrentUser,
    session: SessionDep,
) -> ScheduledPostResponse:
    item = OperationsService(session).schedule(current_user.id, workspace_id, request)
    return ScheduledPostResponse.model_validate(item)


@router.get("/schedule", response_model=list[ScheduledPostResponse])
def scheduled(
    workspace_id: uuid.UUID, current_user: CurrentUser, session: SessionDep
) -> list[ScheduledPostResponse]:
    items = OperationsService(session).scheduled(current_user.id, workspace_id)
    return [ScheduledPostResponse.model_validate(item) for item in items]


@router.post("/schedule/{post_id}/cancel", response_model=ScheduledPostResponse)
def cancel_scheduled(
    workspace_id: uuid.UUID,
    post_id: uuid.UUID,
    current_user: CurrentUser,
    session: SessionDep,
) -> ScheduledPostResponse:
    item = OperationsService(session).cancel(current_user.id, workspace_id, post_id)
    return ScheduledPostResponse.model_validate(item)


@router.post("/schedule/{post_id}/reschedule", response_model=ScheduledPostResponse)
def reschedule_scheduled(
    workspace_id: uuid.UUID,
    post_id: uuid.UUID,
    request: ScheduleRescheduleRequest,
    current_user: CurrentUser,
    session: SessionDep,
) -> ScheduledPostResponse:
    item = OperationsService(session).reschedule(current_user.id, workspace_id, post_id, request)
    return ScheduledPostResponse.model_validate(item)


@router.post("/schedule/{post_id}/retry", response_model=ScheduledPostResponse)
def retry_scheduled(
    workspace_id: uuid.UUID,
    post_id: uuid.UUID,
    current_user: CurrentUser,
    session: SessionDep,
) -> ScheduledPostResponse:
    item = OperationsService(session).retry(current_user.id, workspace_id, post_id)
    return ScheduledPostResponse.model_validate(item)


@router.post("/metrics", response_model=MetricsResponse, status_code=status.HTTP_201_CREATED)
def record_metrics(
    workspace_id: uuid.UUID,
    request: MetricsCreateRequest,
    current_user: CurrentUser,
    session: SessionDep,
) -> MetricsResponse:
    item = OperationsService(session).record_metrics(current_user.id, workspace_id, request)
    return MetricsResponse.model_validate(item)


@router.get("/metrics", response_model=list[MetricsResponse])
def metrics(
    workspace_id: uuid.UUID, current_user: CurrentUser, session: SessionDep
) -> list[MetricsResponse]:
    items = OperationsService(session).metrics(current_user.id, workspace_id)
    return [MetricsResponse.model_validate(item) for item in items]


@router.get("/audit", response_model=list[AuditLogResponse])
def audit(
    workspace_id: uuid.UUID, current_user: CurrentUser, session: SessionDep
) -> list[AuditLogResponse]:
    items = OperationsService(session).audit(current_user.id, workspace_id)
    return [AuditLogResponse.model_validate(item) for item in items]


@router.post("/analytics/poll", response_model=dict[str, int])
def poll_analytics(
    workspace_id: uuid.UUID,
    current_user: CurrentUser,
    session: SessionDep,
    settings: SettingsDep,
) -> dict[str, int]:
    """Run an on-demand provider poll; Celery can call the same service later."""
    OperationsService(session)._access(current_user.id, workspace_id)
    return AnalyticsPoller(session, settings).collect(limit=100)
