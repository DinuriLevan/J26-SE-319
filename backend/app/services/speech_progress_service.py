import uuid
from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.phoneme_progress import PhonemeProgress

MASTERY_ALPHA = 0.3  # weight of the newest attempt in the mastery moving average


def record_unit_attempt(
    db: Session, child_id: uuid.UUID, language: str, unit_label: str, passed: bool, score: float
) -> PhonemeProgress:
    stmt = select(PhonemeProgress).where(
        PhonemeProgress.child_id == child_id,
        PhonemeProgress.language == language,
        PhonemeProgress.unit_label == unit_label,
    )
    row = db.scalars(stmt).one_or_none()
    if row is None:
        row = PhonemeProgress(
            child_id=child_id, language=language, unit_label=unit_label, attempts=0, successes=0, mastery=0.0
        )
        db.add(row)
    row.attempts += 1
    row.successes += int(passed)
    row.last_score = score
    row.last_seen = datetime.now(timezone.utc)
    row.mastery = (1 - MASTERY_ALPHA) * row.mastery + MASTERY_ALPHA * float(passed)
    db.commit()
    db.refresh(row)
    return row


def list_progress(db: Session, child_id: uuid.UUID) -> list[PhonemeProgress]:
    """Lowest mastery first: these are the units to practise next."""
    stmt = (
        select(PhonemeProgress)
        .where(PhonemeProgress.child_id == child_id)
        .order_by(PhonemeProgress.mastery, PhonemeProgress.last_seen)
    )
    return list(db.scalars(stmt))
