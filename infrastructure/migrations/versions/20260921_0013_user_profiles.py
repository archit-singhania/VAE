"""Add customer profile fields.

Revision ID: 20260921_0013
Revises: 20260919_0012
"""

import sqlalchemy as sa
from alembic import op

revision = "20260921_0013"
down_revision = "20260919_0012"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("users") as batch:
        batch.add_column(
            sa.Column(
                "account_type",
                sa.String(length=24),
                nullable=False,
                server_default="creator",
            )
        )
        batch.add_column(sa.Column("brand_name", sa.String(length=160), nullable=True))
        batch.add_column(sa.Column("avatar_url", sa.String(length=2048), nullable=True))


def downgrade() -> None:
    with op.batch_alter_table("users") as batch:
        batch.drop_column("avatar_url")
        batch.drop_column("brand_name")
        batch.drop_column("account_type")
