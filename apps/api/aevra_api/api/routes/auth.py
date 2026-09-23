import uuid
from datetime import UTC, datetime, timedelta

from fastapi import APIRouter, File, Form, Response, UploadFile, status
from sqlalchemy import select

from aevra_api.api.dependencies import CurrentUser, SessionDep, SettingsDep
from aevra_api.db.models import (
    AccountDeletionRequest,
    PaymentSubmission,
    User,
)
from aevra_api.domain.errors import ConflictError
from aevra_api.repositories.tenancy import TenancyRepository
from aevra_api.schemas.tenancy import (
    AccountDeletionCreateRequest,
    AccountDeletionResponse,
    AdminPaymentResponse,
    LoginRequest,
    OnboardingStatusRequest,
    OrganizationResponse,
    PasswordChangeRequest,
    PaymentInstructionsResponse,
    PaymentReviewRequest,
    PaymentStatusResponse,
    PaymentSubmissionRequest,
    ProfileUpdateRequest,
    RegisterRequest,
    RegistrationResponse,
    TokenResponse,
    UserResponse,
    WorkspaceResponse,
)
from aevra_api.security import (
    create_access_token,
    create_onboarding_token,
    decode_onboarding_token,
    hash_password,
    verify_password,
)
from aevra_api.services.media import MediaService
from aevra_api.services.tenancy import TenancyService

router = APIRouter(prefix="/auth", tags=["authentication"])


def set_session_cookie(
    response: Response, token: str, expires_in: int, settings: SettingsDep
) -> None:
    """Set the web session without exposing the token to browser JavaScript."""
    response.set_cookie(
        key=settings.session_cookie_name,
        value=token,
        max_age=expires_in,
        httponly=True,
        secure=settings.use_secure_session_cookie,
        samesite=settings.session_cookie_samesite,
        path="/",
    )


@router.post("/register", response_model=RegistrationResponse, status_code=status.HTTP_201_CREATED)
def register(
    request: RegisterRequest,
    session: SessionDep,
    settings: SettingsDep,
    response: Response,
) -> RegistrationResponse:
    result = TenancyService(session).register(request)
    if not settings.manual_payment_approval_enabled:
        result.user.account_status = "approved"
        result.user.payment_required = False
        session.commit()
        token, expires_in = create_access_token(result.user.id, settings)
        set_session_cookie(response, token, expires_in, settings)
        return RegistrationResponse(
            user=UserResponse.model_validate(result.user),
            organization=OrganizationResponse.model_validate(result.organization),
            workspace=WorkspaceResponse.model_validate(result.workspace),
            token=TokenResponse(access_token=token, expires_in=expires_in),
            account_status=result.user.account_status,
            payment_required=False,
        )

    payment = PaymentSubmission(
        tenant_id=result.organization.id,
        user_id=result.user.id,
        amount=settings.payment_amount,
        currency=settings.payment_currency,
        upi_id_snapshot=settings.payment_upi_id,
        status="pending_payment",
    )
    session.add(payment)
    session.commit()
    onboarding_token, _ = create_onboarding_token(result.user.id, settings)
    return RegistrationResponse(
        user=UserResponse.model_validate(result.user),
        organization=OrganizationResponse.model_validate(result.organization),
        workspace=WorkspaceResponse.model_validate(result.workspace),
        token=None,
        account_status=result.user.account_status,
        payment_required=True,
        onboarding_token=onboarding_token,
    )


@router.post("/login", response_model=TokenResponse)
def login(
    request: LoginRequest,
    session: SessionDep,
    settings: SettingsDep,
    response: Response,
) -> TokenResponse:
    user = TenancyService(session).authenticate(request.email, request.password)
    token, expires_in = create_access_token(user.id, settings)
    set_session_cookie(response, token, expires_in, settings)
    return TokenResponse(access_token=token, expires_in=expires_in)


@router.post("/admin/login", response_model=TokenResponse)
def admin_login(
    request: LoginRequest,
    session: SessionDep,
    settings: SettingsDep,
    response: Response,
) -> TokenResponse:
    user = TenancyService(session).authenticate(request.email, request.password)
    _require_admin(user)
    token, expires_in = create_access_token(user.id, settings)
    set_session_cookie(response, token, expires_in, settings)
    return TokenResponse(access_token=token, expires_in=expires_in)


@router.get("/onboarding/payment-instructions", response_model=PaymentInstructionsResponse)
def payment_instructions(settings: SettingsDep) -> PaymentInstructionsResponse:
    return PaymentInstructionsResponse(
        amount=settings.payment_amount,
        currency=settings.payment_currency,
        upi_id=settings.payment_upi_id,
        qr_url=settings.payment_qr_url,
        support_email=settings.payment_support_email,
        expires_in_days=settings.payment_expiry_days,
    )


@router.post("/onboarding/payment-submissions", response_model=PaymentStatusResponse)
def submit_payment(
    request: PaymentSubmissionRequest,
    current_user: CurrentUser,
    session: SessionDep,
) -> PaymentStatusResponse:
    if current_user.is_admin:
        raise ConflictError("The administrator does not require payment")
    if not request.utr_reference and not request.proof_asset_id:
        raise ConflictError("Provide a UTR/reference number or payment proof")
    if request.utr_reference:
        duplicate = session.scalar(
            select(PaymentSubmission).where(
                PaymentSubmission.utr_reference == request.utr_reference,
                PaymentSubmission.user_id != current_user.id,
            )
        )
        if duplicate is not None:
            raise ConflictError("That UTR/reference has already been submitted")
    item = session.scalar(
        select(PaymentSubmission)
        .where(PaymentSubmission.user_id == current_user.id)
        .order_by(PaymentSubmission.created_at.desc())
    )
    if item is None:
        raise ConflictError("No payment request exists for this account")
    item.utr_reference = request.utr_reference
    item.proof_asset_id = request.proof_asset_id
    item.note = request.note
    item.status = "under_review"
    item.review_history = [
        *item.review_history,
        {
            "action": "submitted",
            "user_id": str(current_user.id),
            "utr": request.utr_reference,
            "at": datetime.now(UTC).isoformat(),
        },
    ]
    current_user.account_status = "under_review"
    session.commit()
    return PaymentStatusResponse(status=item.status, submitted_at=item.updated_at)


@router.post("/onboarding/payment-submissions/public", response_model=PaymentStatusResponse)
def submit_payment_public(
    request: PaymentSubmissionRequest,
    session: SessionDep,
    settings: SettingsDep,
) -> PaymentStatusResponse:
    if not request.onboarding_token:
        raise ConflictError("An onboarding token is required")
    user_id = decode_onboarding_token(request.onboarding_token, settings)
    user = session.get(User, user_id)
    if user is None or user.is_admin:
        raise ConflictError("Payment submission is unavailable for this account")
    if not request.utr_reference and not request.proof_asset_id:
        raise ConflictError("Provide a UTR/reference number or payment proof")
    if request.utr_reference:
        duplicate = session.scalar(
            select(PaymentSubmission).where(
                PaymentSubmission.utr_reference == request.utr_reference,
                PaymentSubmission.user_id != user.id,
            )
        )
        if duplicate is not None:
            raise ConflictError("That UTR/reference has already been submitted")
    item = session.scalar(
        select(PaymentSubmission)
        .where(PaymentSubmission.user_id == user.id)
        .order_by(PaymentSubmission.created_at.desc())
    )
    if item is None:
        raise ConflictError("No payment request exists for this account")
    item.utr_reference = request.utr_reference
    item.proof_asset_id = request.proof_asset_id
    item.note = request.note
    item.status = "under_review"
    item.review_history = [
        *item.review_history,
        {
            "action": "submitted",
            "user_id": str(user.id),
            "utr": request.utr_reference,
            "at": datetime.now(UTC).isoformat(),
        },
    ]
    user.account_status = "under_review"
    session.commit()
    return PaymentStatusResponse(status=item.status, submitted_at=item.updated_at)


@router.post("/onboarding/payment-status/public", response_model=PaymentStatusResponse)
def payment_status_public(
    request: OnboardingStatusRequest,
    session: SessionDep,
    settings: SettingsDep,
) -> PaymentStatusResponse:
    """Let a registrant observe manual review without creating a login session."""
    user_id = decode_onboarding_token(request.onboarding_token, settings)
    user = session.get(User, user_id)
    if user is None or user.is_admin:
        raise ConflictError("Payment status is unavailable for this account")
    item = session.scalar(
        select(PaymentSubmission)
        .where(PaymentSubmission.user_id == user.id)
        .order_by(PaymentSubmission.created_at.desc())
    )
    if item is None:
        raise ConflictError("No payment request exists for this account")
    return PaymentStatusResponse(
        status=item.status,
        admin_note=item.admin_note,
        submitted_at=item.updated_at,
    )


@router.post("/onboarding/payment-submissions/public/proof", response_model=PaymentStatusResponse)
async def submit_payment_proof(
    session: SessionDep,
    settings: SettingsDep,
    onboarding_token: str = Form(...),
    utr_reference: str | None = Form(default=None),
    note: str | None = Form(default=None),
    file: UploadFile = File(...),  # noqa: B008 - FastAPI declares uploads this way.
) -> PaymentStatusResponse:
    user_id = decode_onboarding_token(onboarding_token, settings)
    user = session.get(User, user_id)
    if user is None or user.is_admin:
        raise ConflictError("Payment submission is unavailable for this account")
    if not utr_reference:
        duplicate = None
    else:
        duplicate = session.scalar(
            select(PaymentSubmission).where(
                PaymentSubmission.utr_reference == utr_reference,
                PaymentSubmission.user_id != user.id,
            )
        )
    if duplicate is not None:
        raise ConflictError("That UTR/reference has already been submitted")
    content_type = (file.content_type or "").lower().split(";", 1)[0]
    if content_type not in {"image/jpeg", "image/png", "image/webp"}:
        raise ConflictError("Payment proof must be a JPG, PNG, or WebP file")
    content = await file.read()
    if not content or len(content) > 10 * 1024 * 1024:
        raise ConflictError("Payment proof must be between 1 byte and 10 MB")
    workspaces = TenancyRepository(session).list_workspaces_for_user(user.id)
    if not workspaces:
        raise ConflictError("No workspace exists for this account")
    asset = MediaService(session, settings).upload_asset(
        user.id, workspaces[0].id, None, file.filename or "payment-proof", content_type, content
    )
    item = session.scalar(
        select(PaymentSubmission)
        .where(PaymentSubmission.user_id == user.id)
        .order_by(PaymentSubmission.created_at.desc())
    )
    if item is None:
        raise ConflictError("No payment request exists for this account")
    item.utr_reference = utr_reference
    item.proof_asset_id = asset.id
    item.note = note
    item.status = "under_review"
    item.review_history = [
        *item.review_history,
        {
            "action": "proof_submitted",
            "user_id": str(user.id),
            "asset_id": str(asset.id),
            "at": datetime.now(UTC).isoformat(),
        },
    ]
    user.account_status = "under_review"
    session.commit()
    return PaymentStatusResponse(status=item.status, submitted_at=item.updated_at)


@router.get("/onboarding/payment-status", response_model=PaymentStatusResponse)
def payment_status(current_user: CurrentUser, session: SessionDep) -> PaymentStatusResponse:
    item = session.scalar(
        select(PaymentSubmission)
        .where(PaymentSubmission.user_id == current_user.id)
        .order_by(PaymentSubmission.created_at.desc())
    )
    if item is None:
        raise ConflictError("No payment request exists for this account")
    return PaymentStatusResponse(
        status=item.status, admin_note=item.admin_note, submitted_at=item.updated_at
    )


def _require_admin(user) -> None:
    if not user.is_admin:
        from aevra_api.domain.errors import ForbiddenError

        raise ForbiddenError("Administrator access is required")


@router.get("/admin/payment-submissions", response_model=list[AdminPaymentResponse])
def list_payment_submissions(
    current_user: CurrentUser, session: SessionDep
) -> list[AdminPaymentResponse]:
    _require_admin(current_user)
    rows = session.execute(
        select(PaymentSubmission, User)
        .join(User, User.id == PaymentSubmission.user_id)
        .order_by(PaymentSubmission.created_at.desc())
    ).all()
    return [
        AdminPaymentResponse(
            id=item.id,
            user_id=item.user_id,
            tenant_id=item.tenant_id,
            email=user.email,
            display_name=user.display_name,
            amount=item.amount,
            currency=item.currency,
            utr_reference=item.utr_reference,
            proof_asset_id=item.proof_asset_id,
            status=item.status,
            admin_note=item.admin_note,
            submitted_at=item.updated_at,
        )
        for item, user in rows
    ]


@router.get("/admin/overview", response_model=dict[str, object])
def admin_overview(current_user: CurrentUser, session: SessionDep) -> dict[str, object]:
    """Return non-sensitive tenant and usage KPIs for the sole administrator."""
    _require_admin(current_user)
    from aevra_api.services.admin_reporting import build_admin_overview

    return build_admin_overview(session)


@router.post(
    "/admin/payment-submissions/{submission_id}/approve", response_model=PaymentStatusResponse
)
def approve_payment(
    submission_id: uuid.UUID,
    request: PaymentReviewRequest,
    current_user: CurrentUser,
    session: SessionDep,
) -> PaymentStatusResponse:
    _require_admin(current_user)
    item = session.get(PaymentSubmission, submission_id)
    if item is None:
        raise ConflictError("Payment submission not found")
    if item.status == "approved":
        return PaymentStatusResponse(status=item.status, submitted_at=item.updated_at)
    user = session.get(User, item.user_id)
    if user is None:
        raise ConflictError("Payment user not found")
    item.status = "approved"
    item.admin_note = request.note
    item.reviewed_by = current_user.id
    item.reviewed_at = datetime.now(UTC)
    item.review_history = [
        *item.review_history,
        {
            "action": "approved",
            "admin_id": str(current_user.id),
            "note": request.note,
            "at": item.reviewed_at.isoformat(),
        },
    ]
    user.account_status = "approved"
    user.payment_required = False
    user.approved_at = datetime.now(UTC)
    user.approved_by = current_user.id
    session.commit()
    return PaymentStatusResponse(
        status=item.status, admin_note=item.admin_note, submitted_at=item.updated_at
    )


@router.post(
    "/admin/payment-submissions/{submission_id}/reject", response_model=PaymentStatusResponse
)
def reject_payment(
    submission_id: uuid.UUID,
    request: PaymentReviewRequest,
    current_user: CurrentUser,
    session: SessionDep,
) -> PaymentStatusResponse:
    _require_admin(current_user)
    if not request.note:
        raise ConflictError("A rejection reason is required")
    item = session.get(PaymentSubmission, submission_id)
    if item is None:
        raise ConflictError("Payment submission not found")
    user = session.get(User, item.user_id)
    if user is None:
        raise ConflictError("Payment user not found")
    item.status = "rejected"
    item.admin_note = request.note
    item.reviewed_by = current_user.id
    item.reviewed_at = datetime.now(UTC)
    item.review_history = [
        *item.review_history,
        {
            "action": "rejected",
            "admin_id": str(current_user.id),
            "note": request.note,
            "at": item.reviewed_at.isoformat(),
        },
    ]
    user.account_status = "rejected"
    session.commit()
    return PaymentStatusResponse(
        status=item.status, admin_note=item.admin_note, submitted_at=item.updated_at
    )


@router.get("/me", response_model=UserResponse)
def me(current_user: CurrentUser) -> UserResponse:
    return UserResponse.model_validate(current_user)


@router.patch("/me", response_model=UserResponse)
def update_profile(
    request: ProfileUpdateRequest, current_user: CurrentUser, session: SessionDep
) -> UserResponse:
    duplicate = session.scalar(
        select(User).where(User.email == request.email, User.id != current_user.id)
    )
    if duplicate is not None:
        raise ConflictError("An account with this email already exists")
    current_user.display_name = request.display_name.strip()
    current_user.email = request.email
    current_user.account_type = request.account_type
    current_user.brand_name = request.brand_name.strip() if request.brand_name else None
    current_user.avatar_url = request.avatar_url.strip() if request.avatar_url else None
    session.commit()
    session.refresh(current_user)
    return UserResponse.model_validate(current_user)


@router.post("/change-password", status_code=status.HTTP_204_NO_CONTENT)
def change_password(
    request: PasswordChangeRequest, current_user: CurrentUser, session: SessionDep
) -> Response:
    if not verify_password(request.current_password, current_user.password_hash):
        raise ConflictError("Current password is incorrect")
    current_user.password_hash = hash_password(request.new_password)
    session.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
def logout(response: Response, settings: SettingsDep) -> Response:
    response.delete_cookie(
        key=settings.session_cookie_name,
        path="/",
        secure=settings.use_secure_session_cookie,
        samesite=settings.session_cookie_samesite,
    )
    response.status_code = status.HTTP_204_NO_CONTENT
    return response


@router.post(
    "/account-deletion",
    response_model=AccountDeletionResponse,
    status_code=status.HTTP_202_ACCEPTED,
)
def request_account_deletion(
    request: AccountDeletionCreateRequest,
    current_user: CurrentUser,
    session: SessionDep,
) -> AccountDeletionResponse:
    if request.confirmation_email.strip().lower() != current_user.email.lower():
        raise ConflictError("Confirmation email does not match the signed-in account")
    existing = session.scalar(
        select(AccountDeletionRequest).where(
            AccountDeletionRequest.user_id == current_user.id,
            AccountDeletionRequest.status == "requested",
        )
    )
    if existing is not None:
        return AccountDeletionResponse(
            request_id=existing.id,
            status=existing.status,
            requested_at=existing.requested_at,
            scheduled_for=existing.scheduled_for,
        )
    now = datetime.now(UTC)
    item = AccountDeletionRequest(
        user_id=current_user.id,
        status="requested",
        requested_at=now,
        scheduled_for=now + timedelta(days=30),
    )
    session.add(item)
    session.commit()
    return AccountDeletionResponse(
        request_id=item.id,
        status=item.status,
        requested_at=item.requested_at,
        scheduled_for=item.scheduled_for,
    )


@router.post("/account-deletion/cancel", status_code=status.HTTP_204_NO_CONTENT)
def cancel_account_deletion(
    current_user: CurrentUser,
    session: SessionDep,
    response: Response,
) -> Response:
    """Cancel a requested deletion during the grace period."""
    item = session.scalar(
        select(AccountDeletionRequest).where(
            AccountDeletionRequest.user_id == current_user.id,
            AccountDeletionRequest.status == "requested",
        )
    )
    if item is None:
        raise ConflictError("No cancellable account deletion request exists")
    item.status = "cancelled"
    session.commit()
    response.status_code = status.HTTP_204_NO_CONTENT
    return response


@router.post("/admin/process-deletions", response_model=dict[str, int])
def process_due_deletions(current_user: CurrentUser, session: SessionDep) -> dict[str, int]:
    """Execute due deletion requests without breaking historical media/audit FKs.

    Customer records are irreversibly anonymized and deactivated; immutable
    aggregate usage records remain for accounting and audit integrity.
    """
    _require_admin(current_user)
    now = datetime.now(UTC)
    items = session.scalars(
        select(AccountDeletionRequest).where(
            AccountDeletionRequest.status == "requested",
            AccountDeletionRequest.scheduled_for <= now,
        )
    ).all()
    processed = 0
    for item in items:
        user = session.get(User, item.user_id)
        if user is None:
            item.status = "completed"
            item.completed_at = now
            processed += 1
            continue
        item.status = "processing"
        user.is_active = False
        user.account_status = "deleted"
        user.email = f"deleted+{user.id}@invalid.vae"
        user.display_name = "Deleted account"
        user.brand_name = None
        user.avatar_url = None
        user.password_hash = hash_password(str(uuid.uuid4()))
        item.status = "completed"
        item.completed_at = now
        processed += 1
    session.commit()
    return {"processed": processed}
