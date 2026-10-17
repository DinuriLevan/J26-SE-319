import uuid
from datetime import datetime

from sqlalchemy import DateTime, Float, ForeignKey, Integer, String, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class PhonemeProgress(Base):
    """Speech component: per-child practice record for one unit (akshara / letter chunk)."""

    __tablename__ = "phoneme_progress"
    __table_args__ = (UniqueConstraint("child_id", "language", "unit_label", name="uq_phoneme_progress_child_unit"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    child_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("child_profiles.id"), nullable=False, index=True
    )
    language: Mapped[str] = mapped_column(String(10), nullable=False)
    unit_label: Mapped[str] = mapped_column(String(20), nullable=False)
    attempts: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    successes: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    last_score: Mapped[float | None] = mapped_column(Float, nullable=True)
    last_seen: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    # Exponential moving average of pass (1) / fail (0), alpha 0.3, in [0, 1].
    mastery: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)
