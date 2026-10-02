import uuid

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.learner_progress import LearnerProgress
from app.schemas.learner_progress import LearnerProgressUpdate


def list_learner_progress(
    db: Session, child_id: uuid.UUID, component_name: str | None = None
) -> list[LearnerProgress]:
    stmt = select(LearnerProgress).where(LearnerProgress.child_id == child_id)
    if component_name is not None:
        stmt = stmt.where(LearnerProgress.component_name == component_name)
    return list(db.scalars(stmt))


def upsert_learner_progress(
    db: Session, child_id: uuid.UUID, component_name: str, payload: LearnerProgressUpdate
) -> LearnerProgress:
    stmt = select(LearnerProgress).where(
        LearnerProgress.child_id == child_id, LearnerProgress.component_name == component_name
    )
    progress = db.scalars(stmt).one_or_none()
    if progress is None:
        progress = LearnerProgress(
            child_id=child_id, component_name=component_name, progress_data=payload.progress_data
        )
        db.add(progress)
    else:
        progress.progress_data = payload.progress_data
    db.commit()
    db.refresh(progress)
    return progress
