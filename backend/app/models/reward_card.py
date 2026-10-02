import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class ChildCardUnlock(Base):
    """A child's unlocked card album. The card catalog itself is static and lives in backend code for now."""

    __tablename__ = "child_card_unlocks"
    __table_args__ = (UniqueConstraint("child_id", "card_id", name="uq_child_card_unlock"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    child_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("child_profiles.id"), nullable=False, index=True
    )
    card_id: Mapped[str] = mapped_column(String(50), nullable=False)
    unlocked_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
