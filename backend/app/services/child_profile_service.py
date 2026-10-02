import uuid

from sqlalchemy.orm import Session

from app.models.child_profile import ChildProfile
from app.schemas.child_profile import ChildProfileCreate


def create_or_update_child_profile(db: Session, payload: ChildProfileCreate) -> ChildProfile:
    profile = db.get(ChildProfile, payload.id)
    if profile is None:
        profile = ChildProfile(**payload.model_dump())
        db.add(profile)
    else:
        profile.name = payload.name
        profile.preferred_language = payload.preferred_language
        profile.grade = payload.grade
    db.commit()
    db.refresh(profile)
    return profile


def get_child_profile(db: Session, child_id: uuid.UUID) -> ChildProfile | None:
    return db.get(ChildProfile, child_id)
