import uuid

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.activity_result import ActivityResult
from app.schemas.activity_result import ActivityResultCreate


def create_activity_result(db: Session, payload: ActivityResultCreate) -> ActivityResult:
    result = ActivityResult(**payload.model_dump())
    db.add(result)
    db.commit()
    db.refresh(result)
    return result


def list_activity_results(
    db: Session, child_id: uuid.UUID | None = None, component_name: str | None = None
) -> list[ActivityResult]:
    stmt = select(ActivityResult).order_by(ActivityResult.created_at.desc())
    if child_id is not None:
        stmt = stmt.where(ActivityResult.child_id == child_id)
    if component_name is not None:
        stmt = stmt.where(ActivityResult.component_name == component_name)
    return list(db.scalars(stmt))
