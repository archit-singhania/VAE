import uuid
from datetime import datetime

from pgvector.sqlalchemy import Vector
from sqlalchemy import (
    JSON,
    CheckConstraint,
    DateTime,
    Float,
    ForeignKey,
    ForeignKeyConstraint,
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from aevra_api.db.base import Base, TimestampMixin


class User(TimestampMixin, Base):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    email: Mapped[str] = mapped_column(String(320), unique=True, index=True)
    display_name: Mapped[str] = mapped_column(String(120))
    account_type: Mapped[str] = mapped_column(String(24), default="creator")
    brand_name: Mapped[str | None] = mapped_column(String(160), nullable=True)
    avatar_url: Mapped[str | None] = mapped_column(String(2048), nullable=True)
    password_hash: Mapped[str] = mapped_column(String(512))
    is_active: Mapped[bool] = mapped_column(default=True)
    account_status: Mapped[str] = mapped_column(String(24), default="approved", index=True)
    payment_required: Mapped[bool] = mapped_column(default=False)
    approved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    approved_by: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    is_admin: Mapped[bool] = mapped_column(default=False)
    last_login_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    memberships: Mapped[list["OrganizationMember"]] = relationship(
        back_populates="user", cascade="all, delete-orphan"
    )


class PaymentSubmission(TimestampMixin, Base):
    __tablename__ = "payment_submissions"
    __table_args__ = (
        CheckConstraint(
            "status IN ('pending_payment', 'payment_submitted', 'under_review', "
            "'approved', 'rejected', 'expired')",
            name="valid_payment_submission_status",
        ),
        Index("ix_payment_submissions_status_created", "status", "created_at"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("organizations.id", ondelete="CASCADE"), index=True
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    amount: Mapped[str] = mapped_column(String(32), default="0")
    currency: Mapped[str] = mapped_column(String(8), default="INR")
    upi_id_snapshot: Mapped[str] = mapped_column(String(320), default="")
    utr_reference: Mapped[str | None] = mapped_column(String(128), nullable=True, index=True)
    proof_asset_id: Mapped[uuid.UUID | None] = mapped_column(nullable=True)
    note: Mapped[str | None] = mapped_column(Text, nullable=True)
    status: Mapped[str] = mapped_column(String(24), default="pending_payment", index=True)
    admin_note: Mapped[str | None] = mapped_column(Text, nullable=True)
    reviewed_by: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    reviewed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    review_history: Mapped[list[dict[str, object]]] = mapped_column(JSON, default=list)


class AccountDeletionRequest(TimestampMixin, Base):
    __tablename__ = "account_deletion_requests"
    __table_args__ = (
        CheckConstraint(
            "status IN ('requested', 'processing', 'completed', 'cancelled')",
            name="valid_account_deletion_status",
        ),
        UniqueConstraint("user_id", "status", name="uq_active_account_deletion_request"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    status: Mapped[str] = mapped_column(String(16), default="requested")
    requested_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    scheduled_for: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class OAuthState(TimestampMixin, Base):
    """Short-lived, one-use OAuth state records used to prevent callback replay."""

    __tablename__ = "oauth_states"
    __table_args__ = (
        UniqueConstraint("nonce_hash", name="uq_oauth_states_nonce_hash"),
        Index("ix_oauth_states_expires", "expires_at", "consumed_at"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    nonce_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    workspace_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("workspaces.id", ondelete="CASCADE"), index=True
    )
    provider: Mapped[str] = mapped_column(String(16), nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    consumed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class Organization(TimestampMixin, Base):
    __tablename__ = "organizations"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    name: Mapped[str] = mapped_column(String(160))
    slug: Mapped[str] = mapped_column(String(80), unique=True, index=True)

    memberships: Mapped[list["OrganizationMember"]] = relationship(
        back_populates="organization", cascade="all, delete-orphan"
    )
    workspaces: Mapped[list["Workspace"]] = relationship(
        back_populates="organization", cascade="all, delete-orphan"
    )


class OrganizationMember(TimestampMixin, Base):
    __tablename__ = "organization_members"
    __table_args__ = (
        UniqueConstraint("organization_id", "user_id"),
        CheckConstraint(
            "role IN ('owner', 'admin', 'member', 'viewer')",
            name="valid_organization_role",
        ),
        Index("ix_organization_members_user_org", "user_id", "organization_id"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    organization_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("organizations.id", ondelete="CASCADE"), index=True
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    role: Mapped[str] = mapped_column(String(16), default="member")

    organization: Mapped[Organization] = relationship(back_populates="memberships")
    user: Mapped[User] = relationship(back_populates="memberships")


class Workspace(TimestampMixin, Base):
    __tablename__ = "workspaces"
    __table_args__ = (
        UniqueConstraint("organization_id", "slug"),
        Index("ix_workspaces_organization_created", "organization_id", "created_at"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    organization_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("organizations.id", ondelete="CASCADE"), index=True
    )
    name: Mapped[str] = mapped_column(String(160))
    slug: Mapped[str] = mapped_column(String(80))
    timezone: Mapped[str] = mapped_column(String(64), default="UTC")
    is_active: Mapped[bool] = mapped_column(default=True)

    organization: Mapped[Organization] = relationship(back_populates="workspaces")
    brands: Mapped[list["BrandProfile"]] = relationship(
        back_populates="workspace", cascade="all, delete-orphan"
    )


class BrandProfile(TimestampMixin, Base):
    __tablename__ = "brand_profiles"
    __table_args__ = (
        UniqueConstraint("workspace_id", "slug"),
        UniqueConstraint("id", "workspace_id", name="uq_brand_profiles_id_workspace"),
        CheckConstraint("status IN ('draft', 'active', 'archived')", name="valid_brand_status"),
        Index("ix_brand_profiles_workspace_created", "workspace_id", "created_at"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    workspace_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("workspaces.id", ondelete="CASCADE"), index=True
    )
    name: Mapped[str] = mapped_column(String(160))
    slug: Mapped[str] = mapped_column(String(80))
    description: Mapped[str] = mapped_column(Text, default="")
    website_url: Mapped[str | None] = mapped_column(String(2048), nullable=True)
    industry: Mapped[str | None] = mapped_column(String(120), nullable=True)
    tone_attributes: Mapped[list[str]] = mapped_column(JSON, default=list)
    target_audiences: Mapped[list[str]] = mapped_column(JSON, default=list)
    preferred_ctas: Mapped[list[str]] = mapped_column(JSON, default=list)
    preferred_hashtags: Mapped[list[str]] = mapped_column(JSON, default=list)
    status: Mapped[str] = mapped_column(String(16), default="draft")

    workspace: Mapped[Workspace] = relationship(back_populates="brands")
    rules: Mapped[list["BrandRule"]] = relationship(
        back_populates="brand", cascade="all, delete-orphan"
    )


class BrandRule(TimestampMixin, Base):
    __tablename__ = "brand_rules"
    __table_args__ = (
        ForeignKeyConstraint(
            ["brand_id", "workspace_id"],
            ["brand_profiles.id", "brand_profiles.workspace_id"],
            ondelete="CASCADE",
        ),
        CheckConstraint(
            "category IN ('voice', 'claim', 'cta', 'terminology', 'compliance')",
            name="valid_brand_rule_category",
        ),
        CheckConstraint(
            "enforcement IN ('required', 'preferred', 'prohibited')",
            name="valid_brand_rule_enforcement",
        ),
        CheckConstraint("priority BETWEEN 1 AND 100", name="valid_brand_rule_priority"),
        Index("ix_brand_rules_workspace_brand", "workspace_id", "brand_id"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    workspace_id: Mapped[uuid.UUID] = mapped_column(index=True)
    brand_id: Mapped[uuid.UUID] = mapped_column(index=True)
    created_by_user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="RESTRICT"), index=True
    )
    category: Mapped[str] = mapped_column(String(24))
    enforcement: Mapped[str] = mapped_column(String(16))
    directive: Mapped[str] = mapped_column(Text)
    rationale: Mapped[str | None] = mapped_column(Text, nullable=True)
    priority: Mapped[int] = mapped_column(Integer, default=50)
    is_active: Mapped[bool] = mapped_column(default=True)

    brand: Mapped[BrandProfile] = relationship(back_populates="rules")


class KnowledgeDocument(TimestampMixin, Base):
    __tablename__ = "knowledge_documents"
    __table_args__ = (
        UniqueConstraint("id", "workspace_id", name="uq_knowledge_documents_id_workspace"),
        UniqueConstraint("workspace_id", "checksum", name="uq_knowledge_documents_checksum"),
        ForeignKeyConstraint(
            ["brand_id", "workspace_id"],
            ["brand_profiles.id", "brand_profiles.workspace_id"],
            ondelete="CASCADE",
        ),
        CheckConstraint(
            "source_type IN ('text', 'markdown', 'website', 'pdf')",
            name="valid_knowledge_source_type",
        ),
        CheckConstraint(
            "status IN ('processing', 'ready', 'failed')",
            name="valid_knowledge_status",
        ),
        Index("ix_knowledge_documents_workspace_created", "workspace_id", "created_at"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    workspace_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("workspaces.id", ondelete="CASCADE"), index=True
    )
    brand_id: Mapped[uuid.UUID | None] = mapped_column(nullable=True, index=True)
    created_by_user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="RESTRICT"), index=True
    )
    title: Mapped[str] = mapped_column(String(300))
    source_type: Mapped[str] = mapped_column(String(16))
    source_uri: Mapped[str | None] = mapped_column(String(2048), nullable=True)
    mime_type: Mapped[str | None] = mapped_column(String(120), nullable=True)
    checksum: Mapped[str] = mapped_column(String(64))
    normalized_content: Mapped[str] = mapped_column(Text)
    content_length: Mapped[int] = mapped_column(Integer)
    document_metadata: Mapped[dict[str, str]] = mapped_column(JSON, default=dict)
    status: Mapped[str] = mapped_column(String(16), default="processing")
    error_message: Mapped[str | None] = mapped_column(String(1000), nullable=True)


class KnowledgeChunk(TimestampMixin, Base):
    __tablename__ = "knowledge_chunks"
    __table_args__ = (
        ForeignKeyConstraint(
            ["document_id", "workspace_id"],
            ["knowledge_documents.id", "knowledge_documents.workspace_id"],
            ondelete="CASCADE",
        ),
        UniqueConstraint("document_id", "chunk_index"),
        CheckConstraint("chunk_index >= 0", name="valid_knowledge_chunk_index"),
        CheckConstraint("start_offset >= 0", name="valid_knowledge_start_offset"),
        CheckConstraint("end_offset > start_offset", name="valid_knowledge_end_offset"),
        Index("ix_knowledge_chunks_workspace_document", "workspace_id", "document_id"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    workspace_id: Mapped[uuid.UUID] = mapped_column(index=True)
    document_id: Mapped[uuid.UUID] = mapped_column(index=True)
    chunk_index: Mapped[int] = mapped_column(Integer)
    content: Mapped[str] = mapped_column(Text)
    start_offset: Mapped[int] = mapped_column(Integer)
    end_offset: Mapped[int] = mapped_column(Integer)
    token_count: Mapped[int] = mapped_column(Integer)
    embedding_model: Mapped[str] = mapped_column(String(120))
    embedding: Mapped[list[float]] = mapped_column(Vector(384).with_variant(JSON(), "sqlite"))


class Campaign(TimestampMixin, Base):
    __tablename__ = "campaigns"
    __table_args__ = (
        UniqueConstraint("id", "workspace_id", name="uq_campaigns_id_workspace"),
        ForeignKeyConstraint(
            ["brand_id", "workspace_id"],
            ["brand_profiles.id", "brand_profiles.workspace_id"],
            ondelete="RESTRICT",
        ),
        CheckConstraint(
            "publishing_mode IN ('manual', 'assisted', 'autonomous')",
            name="valid_campaign_publishing_mode",
        ),
        CheckConstraint(
            "status IN ('draft', 'context_retrieval', 'planning', "
            "'content_generation', 'platform_adaptation', 'validation', "
            "'awaiting_approval', 'approved', 'failed', 'cancelled')",
            name="valid_campaign_status",
        ),
        CheckConstraint("current_revision >= 0", name="valid_campaign_revision"),
        Index("ix_campaigns_workspace_created", "workspace_id", "created_at"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    workspace_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("workspaces.id", ondelete="CASCADE"), index=True
    )
    brand_id: Mapped[uuid.UUID] = mapped_column(index=True)
    created_by_user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="RESTRICT"), index=True
    )
    name: Mapped[str] = mapped_column(String(200))
    goal: Mapped[str] = mapped_column(Text)
    product_service: Mapped[str] = mapped_column(String(300))
    audience: Mapped[str] = mapped_column(Text)
    instructions: Mapped[str] = mapped_column(Text, default="")
    platforms: Mapped[list[str]] = mapped_column(JSON, default=list)
    media_types: Mapped[list[str]] = mapped_column(JSON, default=list)
    start_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    publishing_mode: Mapped[str] = mapped_column(String(16), default="manual")
    status: Mapped[str] = mapped_column(String(32), default="draft")
    current_revision: Mapped[int] = mapped_column(Integer, default=0)
    latest_feedback: Mapped[str | None] = mapped_column(Text, nullable=True)
    error_message: Mapped[str | None] = mapped_column(String(1000), nullable=True)


class CampaignRun(TimestampMixin, Base):
    __tablename__ = "campaign_runs"
    __table_args__ = (
        UniqueConstraint("id", "campaign_id", "workspace_id", name="uq_runs_scope"),
        ForeignKeyConstraint(
            ["campaign_id", "workspace_id"],
            ["campaigns.id", "campaigns.workspace_id"],
            ondelete="CASCADE",
        ),
        UniqueConstraint("campaign_id", "run_number", name="uq_campaign_run_number"),
        CheckConstraint(
            "status IN ('running', 'waiting_approval', 'completed', 'failed', 'cancelled')",
            name="valid_campaign_run_status",
        ),
        CheckConstraint("run_number > 0", name="valid_campaign_run_number"),
        Index("ix_campaign_runs_workspace_campaign", "workspace_id", "campaign_id"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    workspace_id: Mapped[uuid.UUID] = mapped_column(index=True)
    campaign_id: Mapped[uuid.UUID] = mapped_column(index=True)
    run_number: Mapped[int] = mapped_column(Integer)
    revision: Mapped[int] = mapped_column(Integer)
    status: Mapped[str] = mapped_column(String(24), default="running")
    current_node: Mapped[str | None] = mapped_column(String(64), nullable=True)
    state_snapshot: Mapped[dict[str, object]] = mapped_column(JSON, default=dict)
    provider_metadata: Mapped[dict[str, object]] = mapped_column(JSON, default=dict)
    started_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    finished_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    error_message: Mapped[str | None] = mapped_column(String(1000), nullable=True)


class CampaignStep(TimestampMixin, Base):
    __tablename__ = "campaign_steps"
    __table_args__ = (
        ForeignKeyConstraint(
            ["run_id", "campaign_id", "workspace_id"],
            ["campaign_runs.id", "campaign_runs.campaign_id", "campaign_runs.workspace_id"],
            ondelete="CASCADE",
        ),
        UniqueConstraint("run_id", "sequence", name="uq_campaign_step_sequence"),
        CheckConstraint("status IN ('completed', 'failed')", name="valid_campaign_step_status"),
        CheckConstraint("sequence > 0", name="valid_campaign_step_sequence"),
        Index("ix_campaign_steps_workspace_run", "workspace_id", "run_id"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    workspace_id: Mapped[uuid.UUID] = mapped_column(index=True)
    campaign_id: Mapped[uuid.UUID] = mapped_column(index=True)
    run_id: Mapped[uuid.UUID] = mapped_column(index=True)
    sequence: Mapped[int] = mapped_column(Integer)
    node_name: Mapped[str] = mapped_column(String(64))
    status: Mapped[str] = mapped_column(String(16))
    input_digest: Mapped[str] = mapped_column(String(64))
    output_snapshot: Mapped[dict[str, object]] = mapped_column(JSON, default=dict)
    citations: Mapped[list[dict[str, object]]] = mapped_column(JSON, default=list)
    duration_ms: Mapped[int] = mapped_column(Integer)
    provider_metadata: Mapped[dict[str, object]] = mapped_column(JSON, default=dict)
    error_message: Mapped[str | None] = mapped_column(String(1000), nullable=True)


class ContentVariant(TimestampMixin, Base):
    __tablename__ = "content_variants"
    __table_args__ = (
        ForeignKeyConstraint(
            ["campaign_id", "workspace_id"],
            ["campaigns.id", "campaigns.workspace_id"],
            ondelete="CASCADE",
        ),
        UniqueConstraint(
            "campaign_id", "revision", "platform", name="uq_variant_campaign_revision_platform"
        ),
        CheckConstraint(
            "platform IN ('linkedin', 'instagram', 'threads', 'x', 'facebook', 'youtube')",
            name="valid_content_platform",
        ),
        CheckConstraint(
            "status IN ('draft', 'approved', 'rejected', 'superseded')",
            name="valid_content_variant_status",
        ),
        CheckConstraint("revision > 0", name="valid_content_variant_revision"),
        CheckConstraint(
            "quality_score >= 0 AND quality_score <= 100",
            name="valid_content_quality_score",
        ),
        Index("ix_content_variants_workspace_campaign", "workspace_id", "campaign_id"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    workspace_id: Mapped[uuid.UUID] = mapped_column(index=True)
    campaign_id: Mapped[uuid.UUID] = mapped_column(index=True)
    revision: Mapped[int] = mapped_column(Integer)
    platform: Mapped[str] = mapped_column(String(16))
    title: Mapped[str | None] = mapped_column(String(300), nullable=True)
    caption: Mapped[str] = mapped_column(Text)
    hashtags: Mapped[list[str]] = mapped_column(JSON, default=list)
    call_to_action: Mapped[str | None] = mapped_column(String(500), nullable=True)
    status: Mapped[str] = mapped_column(String(16), default="draft")
    quality_score: Mapped[float] = mapped_column(Float, default=0.0)
    validation_issues: Mapped[list[str]] = mapped_column(JSON, default=list)
    citations: Mapped[list[dict[str, object]]] = mapped_column(JSON, default=list)
    generated_by_model: Mapped[str] = mapped_column(String(160))
    generation_metadata: Mapped[dict[str, object]] = mapped_column(JSON, default=dict)


class MediaAsset(TimestampMixin, Base):
    """Tenant-scoped generated media and its platform derivatives."""

    __tablename__ = "media_assets"
    __table_args__ = (
        ForeignKeyConstraint(
            ["campaign_id", "workspace_id"],
            ["campaigns.id", "campaigns.workspace_id"],
            ondelete="CASCADE",
        ),
        UniqueConstraint("id", "workspace_id", name="uq_media_assets_id_workspace"),
        CheckConstraint("media_type IN ('image', 'video')", name="valid_media_asset_type"),
        CheckConstraint(
            "asset_role IN ('source', 'generated', 'variant', 'composition')",
            name="valid_media_asset_role",
        ),
        CheckConstraint(
            "status IN ('processing', 'ready', 'failed')", name="valid_media_asset_status"
        ),
        CheckConstraint(
            "platform IS NULL OR platform IN ("
            "'linkedin', 'instagram', 'threads', 'x', 'facebook', 'youtube')",
            name="valid_media_asset_platform",
        ),
        CheckConstraint("bytes_size >= 0", name="valid_media_asset_bytes"),
        CheckConstraint("width IS NULL OR width > 0", name="valid_media_asset_width"),
        CheckConstraint("height IS NULL OR height > 0", name="valid_media_asset_height"),
        CheckConstraint(
            "duration_seconds IS NULL OR duration_seconds >= 0",
            name="valid_media_asset_duration",
        ),
        Index("ix_media_assets_workspace_created", "workspace_id", "created_at"),
        Index("ix_media_assets_workspace_campaign", "workspace_id", "campaign_id"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    workspace_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("workspaces.id", ondelete="CASCADE"), index=True
    )
    campaign_id: Mapped[uuid.UUID | None] = mapped_column(index=True, nullable=True)
    created_by_user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="RESTRICT"), index=True
    )
    parent_asset_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("media_assets.id", ondelete="SET NULL"), nullable=True, index=True
    )
    media_type: Mapped[str] = mapped_column(String(16))
    asset_role: Mapped[str] = mapped_column(String(16), default="generated")
    platform: Mapped[str | None] = mapped_column(String(16), nullable=True)
    status: Mapped[str] = mapped_column(String(16), default="processing")
    storage_key: Mapped[str] = mapped_column(String(512), unique=True)
    filename: Mapped[str] = mapped_column(String(255))
    mime_type: Mapped[str] = mapped_column(String(120))
    bytes_size: Mapped[int] = mapped_column(Integer, default=0)
    sha256: Mapped[str] = mapped_column(String(64))
    width: Mapped[int | None] = mapped_column(Integer, nullable=True)
    height: Mapped[int | None] = mapped_column(Integer, nullable=True)
    duration_seconds: Mapped[float | None] = mapped_column(Float, nullable=True)
    generation_provider: Mapped[str | None] = mapped_column(String(120), nullable=True)
    prompt: Mapped[str | None] = mapped_column(Text, nullable=True)
    asset_metadata: Mapped[dict[str, object]] = mapped_column(JSON, default=dict)
    error_message: Mapped[str | None] = mapped_column(String(1000), nullable=True)


class SocialAccount(TimestampMixin, Base):
    __tablename__ = "social_accounts"
    __table_args__ = (
        UniqueConstraint(
            "workspace_id", "platform", "external_account_id", name="uq_social_account_identity"
        ),
        CheckConstraint(
            "platform IN ('linkedin', 'instagram', 'threads', 'x', 'facebook', 'youtube')",
            name="valid_social_account_platform",
        ),
        CheckConstraint(
            "status IN ('connected', 'paused', 'revoked')", name="valid_social_account_status"
        ),
        Index("ix_social_accounts_workspace_platform", "workspace_id", "platform"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    workspace_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("workspaces.id", ondelete="CASCADE"), index=True
    )
    created_by_user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="RESTRICT"), index=True
    )
    platform: Mapped[str] = mapped_column(String(16))
    external_account_id: Mapped[str] = mapped_column(String(300))
    display_name: Mapped[str] = mapped_column(String(200))
    status: Mapped[str] = mapped_column(String(16), default="connected")
    # Encrypted provider tokens are intentionally opaque to all API responses.
    # 2 KiB accommodates refresh-token envelopes without truncation.
    access_token_ref: Mapped[str] = mapped_column(String(2048))
    refresh_token_ref: Mapped[str | None] = mapped_column(String(2048), nullable=True)
    access_token_expires_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    granted_scopes: Mapped[list[str]] = mapped_column(JSON, default=list)
    capabilities: Mapped[list[str]] = mapped_column(JSON, default=list)
    account_metadata: Mapped[dict[str, object]] = mapped_column(JSON, default=dict)
    last_verified_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )


class PublishJob(TimestampMixin, Base):
    __tablename__ = "publish_jobs"
    __table_args__ = (
        ForeignKeyConstraint(
            ["campaign_id", "workspace_id"],
            ["campaigns.id", "campaigns.workspace_id"],
            ondelete="CASCADE",
        ),
        UniqueConstraint("workspace_id", "idempotency_key", name="uq_publish_job_idempotency"),
        CheckConstraint(
            "status IN ('queued', 'publishing', 'published', 'verified', 'failed', 'cancelled')",
            name="valid_publish_job_status",
        ),
        Index("ix_publish_jobs_workspace_created", "workspace_id", "created_at"),
        Index("ix_publish_jobs_workspace_campaign", "workspace_id", "campaign_id"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    workspace_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("workspaces.id", ondelete="CASCADE"), index=True
    )
    campaign_id: Mapped[uuid.UUID | None] = mapped_column(index=True, nullable=True)
    social_account_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("social_accounts.id", ondelete="RESTRICT"), index=True
    )
    created_by_user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="RESTRICT"), index=True
    )
    idempotency_key: Mapped[str] = mapped_column(String(160))
    status: Mapped[str] = mapped_column(String(16), default="queued")
    payload: Mapped[dict[str, object]] = mapped_column(JSON, default=dict)
    external_post_id: Mapped[str | None] = mapped_column(String(300), nullable=True)
    external_url: Mapped[str | None] = mapped_column(String(2048), nullable=True)
    attempts: Mapped[int] = mapped_column(Integer, default=0)
    retryable: Mapped[bool] = mapped_column(default=False)
    error_message: Mapped[str | None] = mapped_column(String(1000), nullable=True)
    published_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    verified_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class ScheduledPost(TimestampMixin, Base):
    __tablename__ = "scheduled_posts"
    __table_args__ = (
        ForeignKeyConstraint(
            ["campaign_id", "workspace_id"],
            ["campaigns.id", "campaigns.workspace_id"],
            ondelete="CASCADE",
        ),
        UniqueConstraint("workspace_id", "idempotency_key", name="uq_scheduled_post_idempotency"),
        CheckConstraint(
            "status IN ('scheduled', 'processing', 'published', 'failed', 'cancelled')",
            name="valid_scheduled_post_status",
        ),
        Index("ix_scheduled_posts_workspace_due", "workspace_id", "scheduled_for", "status"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    workspace_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("workspaces.id", ondelete="CASCADE"), index=True
    )
    campaign_id: Mapped[uuid.UUID | None] = mapped_column(index=True, nullable=True)
    social_account_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("social_accounts.id", ondelete="RESTRICT"), index=True
    )
    created_by_user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="RESTRICT"), index=True
    )
    idempotency_key: Mapped[str] = mapped_column(String(160))
    scheduled_for: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    status: Mapped[str] = mapped_column(String(16), default="scheduled")
    payload: Mapped[dict[str, object]] = mapped_column(JSON, default=dict)
    attempts: Mapped[int] = mapped_column(Integer, default=0)
    error_message: Mapped[str | None] = mapped_column(String(1000), nullable=True)
    published_job_id: Mapped[uuid.UUID | None] = mapped_column(nullable=True, index=True)


class PostMetric(TimestampMixin, Base):
    __tablename__ = "post_metrics"
    __table_args__ = (
        UniqueConstraint(
            "workspace_id", "external_post_id", "collected_at", name="uq_post_metric_snapshot"
        ),
        CheckConstraint("impressions >= 0", name="valid_metric_impressions"),
        CheckConstraint("engagements >= 0", name="valid_metric_engagements"),
        Index("ix_post_metrics_workspace_collected", "workspace_id", "collected_at"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    workspace_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("workspaces.id", ondelete="CASCADE"), index=True
    )
    social_account_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("social_accounts.id", ondelete="RESTRICT"), index=True
    )
    external_post_id: Mapped[str] = mapped_column(String(300), index=True)
    collected_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    impressions: Mapped[int] = mapped_column(Integer, default=0)
    engagements: Mapped[int] = mapped_column(Integer, default=0)
    clicks: Mapped[int] = mapped_column(Integer, default=0)
    likes: Mapped[int] = mapped_column(Integer, default=0)
    comments: Mapped[int] = mapped_column(Integer, default=0)
    shares: Mapped[int] = mapped_column(Integer, default=0)
    metric_metadata: Mapped[dict[str, object]] = mapped_column(JSON, default=dict)


class AuditLog(TimestampMixin, Base):
    __tablename__ = "audit_logs"
    __table_args__ = (
        Index("ix_audit_logs_workspace_created", "workspace_id", "created_at"),
        Index("ix_audit_logs_workspace_action", "workspace_id", "action"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    workspace_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("workspaces.id", ondelete="CASCADE"), index=True
    )
    actor_user_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True
    )
    action: Mapped[str] = mapped_column(String(100))
    resource_type: Mapped[str] = mapped_column(String(80))
    resource_id: Mapped[str | None] = mapped_column(String(300), nullable=True)
    request_id: Mapped[str | None] = mapped_column(String(120), nullable=True)
    details: Mapped[dict[str, object]] = mapped_column(JSON, default=dict)
