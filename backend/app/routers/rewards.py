import uuid

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.db import get_db
from app.schemas.reward_card import CardUnlockCreate, CardUnlockRead
from app.services import reward_service

router = APIRouter(prefix="/rewards", tags=["rewards"])


@router.get("/{child_id}", response_model=list[CardUnlockRead])
def get_rewards(child_id: uuid.UUID, db: Session = Depends(get_db)) -> list[CardUnlockRead]:
    unlocks = reward_service.list_card_unlocks(db, child_id)
    return [CardUnlockRead.model_validate(u) for u in unlocks]


@router.post("/{child_id}/unlock", response_model=CardUnlockRead)
def unlock_card(child_id: uuid.UUID, payload: CardUnlockCreate, db: Session = Depends(get_db)) -> CardUnlockRead:
    unlock = reward_service.unlock_card(db, child_id, payload)
    return CardUnlockRead.model_validate(unlock)
