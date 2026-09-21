import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator


class RegisterRequest(BaseModel):
    email: str = Field(min_length=3, max_length=320)
    # Temporary staging policy: production must restore a stronger minimum
    # before public registration is enabled.
    password: str = Field(min_length=1, max_length=128)
    display_name: str = Field(min_length=1, max_length=120)
    organization_name: str = Field(min_length=2, max_length=160)
    workspace_name: str = Field(min_length=2, max_length=160)
    account_type: str = Field(default="creator", pattern="^(creator|business)$")
    brand_name: str | None = Field(default=None, max_length=160)
    timezone: str = Field(default="UTC", min_length=1, max_length=64)

    @field_validator("email")
    @classmethod
    def normalize_email(cls, value: str) -> str:
        normalized = value.strip().lower()
        if normalized.count("@") != 1 or "." not in normalized.rsplit("@", 1)[1]:
            raise ValueError("Enter a valid email address")
        return normalized


class LoginRequest(BaseModel):
    email: str = Field(min_length=3, max_length=320)
    password: str = Field(min_length=1, max_length=128)


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int


class UserResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    email: str
    display_name: str
    is_active: bool
    is_admin: bool = False
    account_status: str = "approved"
    account_type: str = "creator"
    brand_name: str | None = None
    avatar_url: str | None = None
    created_at: datetime


class ProfileUpdateRequest(BaseModel):
    display_name: str = Field(min_length=1, max_length=120)
    email: str = Field(min_length=3, max_length=320)
    account_type: str = Field(pattern="^(creator|business)$")
    brand_name: str | None = Field(default=None, max_length=160)
    avatar_url: str | None = Field(default=None, max_length=2048)

    @field_validator("email")
    @classmethod
    def normalize_profile_email(cls, value: str) -> str:
        normalized = value.strip().lower()
        if normalized.count("@") != 1 or "." not in normalized.rsplit("@", 1)[1]:
            raise ValueError("Enter a valid email address")
        return normalized


class PasswordChangeRequest(BaseModel):
    current_password: str = Field(min_length=1, max_length=128)
    new_password: str = Field(min_length=8, max_length=128)


class OrganizationResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    name: str
    slug: str
    created_at: datetime


class WorkspaceResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    organization_id: uuid.UUID
    name: str
    slug: str
    timezone: str
    is_active: bool
    created_at: datetime


class RegistrationResponse(BaseModel):
    user: UserResponse
    organization: OrganizationResponse
    workspace: WorkspaceResponse
    token: TokenResponse | None = None
    account_status: str = "pending_payment"
    payment_required: bool = True
    onboarding_token: str | None = None


class PaymentInstructionsResponse(BaseModel):
    amount: str
    currency: str
    upi_id: str
    qr_url: str
    support_email: str
    expires_in_days: int


class PaymentSubmissionRequest(BaseModel):
    onboarding_token: str | None = None
    utr_reference: str | None = Field(default=None, max_length=128)
    proof_asset_id: uuid.UUID | None = None
    note: str | None = Field(default=None, max_length=1000)


class OnboardingStatusRequest(BaseModel):
    onboarding_token: str = Field(min_length=1)


class PaymentStatusResponse(BaseModel):
    status: str
    admin_note: str | None = None
    submitted_at: datetime | None = None


class AdminPaymentResponse(PaymentStatusResponse):
    id: uuid.UUID
    user_id: uuid.UUID
    tenant_id: uuid.UUID
    email: str
    display_name: str
    amount: str
    currency: str
    utr_reference: str | None = None
    proof_asset_id: uuid.UUID | None = None


class PaymentReviewRequest(BaseModel):
    note: str | None = Field(default=None, max_length=1000)


class AccountDeletionResponse(BaseModel):
    request_id: uuid.UUID
    status: str
    requested_at: datetime
    scheduled_for: datetime


class AccountDeletionCreateRequest(BaseModel):
    confirmation_email: str = Field(min_length=3, max_length=320)


class WorkspaceCreateRequest(BaseModel):
    name: str = Field(min_length=2, max_length=160)
    timezone: str = Field(default="UTC", min_length=1, max_length=64)
