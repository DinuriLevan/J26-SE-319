import uuid

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.reward_card import ChildCardUnlock
from app.schemas.reward_card import CardUnlockCreate


def list_card_unlocks(db: Session, child_id: uuid.UUID) -> list[ChildCardUnlock]:
    stmt = select(ChildCardUnlock).where(ChildCardUnlock.child_id == child_id)
    return list(db.scalars(stmt))


def unlock_card(db: Session, child_id: uuid.UUID, payload: CardUnlockCreate) -> ChildCardUnlock:
    stmt = select(ChildCardUnlock).where(
        ChildCardUnlock.child_id == child_id, ChildCardUnlock.card_id == payload.card_id
    )
    existing = db.scalars(stmt).one_or_none()
    if existing is not None:
        return existing

    unlock = ChildCardUnlock(child_id=child_id, card_id=payload.card_id)
    db.add(unlock)
    db.commit()
    db.refresh(unlock)
    return unlock
