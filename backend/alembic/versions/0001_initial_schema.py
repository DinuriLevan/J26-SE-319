"""initial schema: child_profiles, learner_progress, activity_results, child_card_unlocks

Revision ID: 0001
Revises:
Create Date: 2026-10-02

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "0001"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "child_profiles",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("name", sa.String(length=100), nullable=False),
        sa.Column("preferred_language", sa.String(length=10), nullable=False),
        sa.Column("grade", sa.Integer(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )

    op.create_table(
        "learner_progress",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("child_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("child_profiles.id"), nullable=False),
        sa.Column("component_name", sa.String(length=50), nullable=False),
        sa.Column("progress_data", postgresql.JSONB(), nullable=False),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            onupdate=sa.func.now(),
            nullable=False,
        ),
        sa.UniqueConstraint("child_id", "component_name", name="uq_learner_progress_child_component"),
    )
    op.create_index("ix_learner_progress_child_id", "learner_progress", ["child_id"])
    op.create_index("ix_learner_progress_component_name", "learner_progress", ["component_name"])

    op.create_table(
        "activity_results",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("child_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("child_profiles.id"), nullable=False),
        sa.Column("component_name", sa.String(length=50), nullable=False),
        sa.Column("activity_id", sa.String(length=100), nullable=False),
        sa.Column("result_payload", postgresql.JSONB(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_activity_results_child_id", "activity_results", ["child_id"])
    op.create_index("ix_activity_results_component_name", "activity_results", ["component_name"])
    op.create_index("ix_activity_results_created_at", "activity_results", ["created_at"])

    op.create_table(
        "child_card_unlocks",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("child_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("child_profiles.id"), nullable=False),
        sa.Column("card_id", sa.String(length=50), nullable=False),
        sa.Column("unlocked_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint("child_id", "card_id", name="uq_child_card_unlock"),
    )
    op.create_index("ix_child_card_unlocks_child_id", "child_card_unlocks", ["child_id"])


def downgrade() -> None:
    op.drop_table("child_card_unlocks")
    op.drop_table("activity_results")
    op.drop_table("learner_progress")
    op.drop_table("child_profiles")
