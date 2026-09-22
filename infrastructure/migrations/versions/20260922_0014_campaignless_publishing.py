"""Allow publishing uploaded/generated assets without a campaign."""

import sqlalchemy as sa
from alembic import op

revision = "20260922_0014"
down_revision = "20260921_0013"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("publish_jobs") as batch:
        batch.alter_column("campaign_id", existing_type=sa.Uuid(), nullable=True)
    with op.batch_alter_table("scheduled_posts") as batch:
        batch.alter_column("campaign_id", existing_type=sa.Uuid(), nullable=True)


def downgrade() -> None:
    with op.batch_alter_table("scheduled_posts") as batch:
        batch.alter_column("campaign_id", existing_type=sa.Uuid(), nullable=False)
    with op.batch_alter_table("publish_jobs") as batch:
        batch.alter_column("campaign_id", existing_type=sa.Uuid(), nullable=False)
