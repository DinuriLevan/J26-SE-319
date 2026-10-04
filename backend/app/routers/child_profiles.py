import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.db import get_db
from app.schemas.child_profile import ChildProfileCreate, ChildProfileRead
from app.services import child_profile_service

router = APIRouter(prefix="/child-profiles", tags=["child-profiles"])


@router.post("", response_model=ChildProfileRead)
def create_child_profile(payload: ChildProfileCreate, db: Session = Depends(get_db)) -> ChildProfileRead:
    profile = child_profile_service.create_or_update_child_profile(db, payload)
    return ChildProfileRead.model_validate(profile)


@router.get("/{child_id}", response_model=ChildProfileRead)
def get_child_profile(child_id: uuid.UUID, db: Session = Depends(get_db)) -> ChildProfileRead:
    profile = child_profile_service.get_child_profile(db, child_id)
    if profile is None:
        raise HTTPException(status_code=404, detail="Child profile not found")
    return ChildProfileRead.model_validate(profile)
