import uuid

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.db import get_db
from app.schemas.activity_result import ActivityResultCreate, ActivityResultRead
from app.services import activity_result_service

router = APIRouter(prefix="/activity-results", tags=["activity-results"])


@router.post("", response_model=ActivityResultRead)
def submit_activity_result(payload: ActivityResultCreate, db: Session = Depends(get_db)) -> ActivityResultRead:
    result = activity_result_service.create_activity_result(db, payload)
    return ActivityResultRead.model_validate(result)


@router.get("", response_model=list[ActivityResultRead])
def list_activity_results(
    child_id: uuid.UUID | None = None,
    component_name: str | None = None,
    db: Session = Depends(get_db),
) -> list[ActivityResultRead]:
    results = activity_result_service.list_activity_results(db, child_id, component_name)
    return [ActivityResultRead.model_validate(r) for r in results]
