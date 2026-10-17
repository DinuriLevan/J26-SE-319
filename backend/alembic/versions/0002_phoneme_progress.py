"""speech: phoneme_progress (per-child unit practice record)

Revision ID: 0002
Revises: 0001
Create Date: 2026-10-16

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "0002"
down_revision: Union[str, None] = "0001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "phoneme_progress",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("child_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("child_profiles.id"), nullable=False),
        sa.Column("language", sa.String(length=10), nullable=False),
        sa.Column("unit_label", sa.String(length=20), nullable=False),
        sa.Column("attempts", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("successes", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("last_score", sa.Float(), nullable=True),
        sa.Column("last_seen", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("mastery", sa.Float(), nullable=False, server_default="0"),
        sa.UniqueConstraint("child_id", "language", "unit_label", name="uq_phoneme_progress_child_unit"),
    )
    op.create_index("ix_phoneme_progress_child_id", "phoneme_progress", ["child_id"])


def downgrade() -> None:
    op.drop_index("ix_phoneme_progress_child_id", table_name="phoneme_progress")
    op.drop_table("phoneme_progress")
