import re
import uuid
from dataclasses import dataclass
from datetime import UTC, datetime

from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from aevra_api.db.models import Organization, OrganizationMember, User, Workspace
from aevra_api.domain.errors import (
    AuthenticationError,
    ConflictError,
    ForbiddenError,
    NotFoundError,
)
from aevra_api.repositories.tenancy import TenancyRepository
from aevra_api.schemas.tenancy import RegisterRequest, WorkspaceCreateRequest
from aevra_api.security import hash_password, verify_password


@dataclass(frozen=True)
class RegistrationResult:
    user: User
    organization: Organization
    workspace: Workspace


def slugify(value: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", value.strip().lower()).strip("-")
    return slug[:64] or "workspace"


class TenancyService:
    def __init__(self, session: Session) -> None:
        self.session = session
        self.repository = TenancyRepository(session)

    def _available_organization_slug(self, name: str) -> str:
        base = slugify(name)
        candidate = base
        suffix = 2
        while self.repository.organization_slug_exists(candidate):
            candidate = f"{base[:70]}-{suffix}"
            suffix += 1
        return candidate

    def _available_workspace_slug(self, organization_id: uuid.UUID, name: str) -> str:
        base = slugify(name)
        candidate = base
        suffix = 2
        while self.repository.workspace_slug_exists(organization_id, candidate):
            candidate = f"{base[:70]}-{suffix}"
            suffix += 1
        return candidate

    def register(self, request: RegisterRequest) -> RegistrationResult:
        if self.repository.get_user_by_email(request.email):
            raise ConflictError("An account with this email already exists")

        user = User(
            email=request.email,
            display_name=request.display_name.strip(),
            account_type=request.account_type,
            brand_name=(request.brand_name or request.organization_name).strip(),
            password_hash=hash_password(request.password),
            account_status="pending_payment",
            payment_required=True,
            is_active=True,
        )
        organization = Organization(
            name=request.organization_name.strip(),
            slug=self._available_organization_slug(request.organization_name),
        )
        workspace = Workspace(
            organization=organization,
            name=request.workspace_name.strip(),
            slug=slugify(request.workspace_name),
            timezone=request.timezone,
        )
        membership = OrganizationMember(
            organization=organization,
            user=user,
            role="owner",
        )
        self.repository.add_user(user)
        self.repository.add_organization(organization)
        self.repository.add_membership(membership)
        self.repository.add_workspace(workspace)

        try:
            self.session.commit()
        except IntegrityError as exc:
            self.session.rollback()
            raise ConflictError("Registration conflicts with an existing account") from exc

        return RegistrationResult(user=user, organization=organization, workspace=workspace)

    def authenticate(self, email: str, password: str) -> User:
        user = self.repository.get_user_by_email(email)
        if user is None or not user.is_active or not verify_password(password, user.password_hash):
            raise AuthenticationError("Incorrect email or password")
        if not user.is_admin and user.account_status != "approved":
            raise AuthenticationError(
                f"Account is {user.account_status}; payment approval is required"
            )
        user.last_login_at = datetime.now(UTC)
        self.session.commit()
        return user

    def require_user(self, user_id: uuid.UUID) -> User:
        user = self.repository.get_user(user_id)
        if user is None or not user.is_active:
            raise AuthenticationError("User is unavailable")
        return user

    def list_workspaces(self, user_id: uuid.UUID) -> list[Workspace]:
        return self.repository.list_workspaces_for_user(user_id)

    def get_workspace(self, user_id: uuid.UUID, workspace_id: uuid.UUID) -> Workspace:
        workspace = self.repository.get_workspace_for_user(user_id, workspace_id)
        if workspace is None:
            raise NotFoundError("Workspace not found")
        return workspace

    def create_workspace(
        self,
        user_id: uuid.UUID,
        organization_id: uuid.UUID,
        request: WorkspaceCreateRequest,
    ) -> Workspace:
        membership = self.repository.get_membership(user_id, organization_id)
        if membership is None or membership.role not in {"owner", "admin"}:
            raise ForbiddenError("Organization administrator access is required")

        workspace = Workspace(
            organization_id=organization_id,
            name=request.name.strip(),
            slug=self._available_workspace_slug(organization_id, request.name),
            timezone=request.timezone,
        )
        self.repository.add_workspace(workspace)
        try:
            self.session.commit()
        except IntegrityError as exc:
            self.session.rollback()
            raise ConflictError("A workspace with this identity already exists") from exc
        return workspace
