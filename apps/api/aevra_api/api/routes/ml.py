import threading
import uuid
from typing import Literal

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from aevra_api.api.dependencies import CurrentUser, SessionDep
from aevra_api.services.ml_insights import analyze, load_history

router = APIRouter(prefix="/workspaces/{workspace_id}/ml", tags=["machine-learning"])
# Prevent concurrent CPU-heavy fits per worker; the client can explicitly retry.
_inference_slot = threading.BoundedSemaphore(1)


class InsightRequest(BaseModel):
    draft: str = Field(default="", max_length=6000)
    platform: Literal["instagram", "facebook", "linkedin", "threads", "x", "youtube"] = "instagram"


@router.post("/insights", response_model=dict[str, object])
def insights(
    workspace_id: uuid.UUID, request: InsightRequest, current_user: CurrentUser, session: SessionDep
) -> dict[str, object]:
    """Read-only ML analysis; no draft/model persistence or provider calls."""
    if not _inference_slot.acquire(blocking=False):
        raise HTTPException(
            status_code=429,
            detail="ML analysis is busy. Retry shortly.",
            headers={"Retry-After": "5"},
        )
    try:
        history = load_history(session, current_user.id, workspace_id)
        return analyze(history, request.draft, request.platform)
    finally:
        _inference_slot.release()
