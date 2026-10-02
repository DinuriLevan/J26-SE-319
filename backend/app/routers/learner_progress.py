import uuid

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.db import get_db
from app.schemas.learner_progress import LearnerProgressRead, LearnerProgressUpdate
from app.services import learner_progress_service

router = APIRouter(prefix="/learner-progress", tags=["learner-progress"])


@router.get("/{child_id}", response_model=list[LearnerProgressRead])
def get_learner_progress(
    child_id: uuid.UUID,
    component_name: str | None = None,
    db: Session = Depends(get_db),
) -> list[LearnerProgressRead]:
    progress = learner_progress_service.list_learner_progress(db, child_id, component_name)
    return [LearnerProgressRead.model_validate(p) for p in progress]


@router.put("/{child_id}/{component_name}", response_model=LearnerProgressRead)
def upsert_learner_progress(
    child_id: uuid.UUID,
    component_name: str,
    payload: LearnerProgressUpdate,
    db: Session = Depends(get_db),
) -> LearnerProgressRead:
    progress = learner_progress_service.upsert_learner_progress(db, child_id, component_name, payload)
    return LearnerProgressRead.model_validate(progress)
