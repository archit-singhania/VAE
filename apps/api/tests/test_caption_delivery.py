import io
import time
import uuid
from datetime import UTC, datetime, timedelta
from urllib.parse import urlsplit

import pytest
from conftest import bearer, register_account
from PIL import Image
from reportlab.pdfgen import canvas

from aevra_api.config import Settings, get_settings
from aevra_api.db.models import PublishJob, ScheduledPost, SocialAccount
from aevra_api.main import app
from aevra_api.publishing.contracts import MockSocialPublisher, PublisherError
from aevra_api.schemas.publishing import PublishRequest
from aevra_api.services.media import prompt_filename
from aevra_api.services.media_delivery import delivery_urls, signature
from aevra_api.services.publishing import PublishingService


def setup_media(client, tmp_path):
    settings = Settings(
        _env_file=None,
        storage_backend="local",
        image_provider="deterministic",
        secret_key="test-secret-key-that-is-at-least-thirty-two-characters",
        database_url="sqlite://",
        media_root=str(tmp_path),
        manual_payment_approval_enabled=False,
        public_api_base_url="https://delivery.example.test",
    )
    app.dependency_overrides[get_settings] = lambda: settings
    owner = register_account(
        client, email="media@example.test", organization_name="Studio", workspace_name="Studio"
    )
    root = f"/api/v1/workspaces/{owner['workspace']['id']}"
    buffer = io.BytesIO()
    Image.new("RGB", (10, 10), "red").save(buffer, format="PNG")
    response = client.post(
        f"{root}/media/assets/upload",
        headers=bearer(owner),
        files={"file": ("My launch.png", buffer.getvalue(), "image/png")},
    )
    assert response.status_code == 201, response.text
    return owner, root, response.json(), settings


def test_prompt_names_are_safe_readable_and_unique():
    one, two = uuid.uuid4(), uuid.uuid4()
    assert prompt_filename("A calm sunrise over the ocean", one).startswith(
        "a-calm-sunrise-over-the-ocean-"
    )
    assert prompt_filename("../../evil\r\nHeader:", one).startswith("evil-header-")
    assert prompt_filename("☀", one).startswith("creative-")
    assert prompt_filename("coffee", one) != prompt_filename("coffee", two)
    assert len(prompt_filename("a" * 4000, one)) < 100


def test_pair_caption_persists_and_is_workspace_scoped(client, tmp_path):
    owner, root, asset, _ = setup_media(client, tmp_path)
    assert asset["filename"] == "My launch.png"
    path = f"{root}/media/assets/{asset['id']}/caption"
    response = client.patch(path, headers=bearer(owner), json={"caption": "Morning launch #studio"})
    assert response.status_code == 200, response.text
    assert (
        client.get(f"{root}/media/assets", headers=bearer(owner)).json()[0]["asset_metadata"][
            "caption"
        ]
        == "Morning launch #studio"
    )
    other = register_account(
        client, email="other@example.test", organization_name="Other", workspace_name="Other"
    )
    assert (
        client.patch(path, headers=bearer(other), json={"caption": "overwrite"}).status_code == 404
    )
    assert (
        client.patch(path, headers=bearer(owner), json={"caption": "a" * 30001}).status_code == 422
    )


def test_caption_import_text_pdf_limits_and_no_asset_creation(client, tmp_path):
    owner, root, _, _ = setup_media(client, tmp_path)

    def upload(name, content):
        return client.post(
            f"{root}/media/captions/extract", headers=bearer(owner), files={"file": (name, content)}
        )

    assert upload("caption.txt", b"New morning #launch").json()["text"] == "New morning #launch"
    pdf = io.BytesIO()
    doc = canvas.Canvas(pdf)
    doc.drawString(72, 720, "A new story #studio")
    doc.save()
    assert "#studio" in upload("caption.pdf", pdf.getvalue()).json()["text"]
    for name, content in [
        ("bad.pdf", b"bad"),
        ("a.exe", b"bad"),
        ("huge.txt", b"x" * (2 * 1024 * 1024 + 1)),
        ("long.txt", b"x" * 30001),
        ("empty.txt", b""),
    ]:
        assert upload(name, content).status_code >= 400
    assert len(client.get(f"{root}/media/assets", headers=bearer(owner)).json()) == 1


def test_delivery_links_are_expiring_asset_bound_and_downloadable(client, tmp_path, session):
    owner, root, asset, settings = setup_media(client, tmp_path)
    wid, uid = uuid.UUID(owner["workspace"]["id"]), uuid.UUID(owner["user"]["id"])
    link = delivery_urls(session, settings, uid, wid, [asset["download_url"]])[0]
    parsed = urlsplit(link)
    client.cookies.clear()
    response = client.get(parsed.path + "?" + parsed.query)
    assert response.status_code == 200
    assert response.headers["cache-control"] == "private, no-store"
    assert (
        client.get(
            parsed.path + "?" + parsed.query.replace("signature=", "signature=bad")
        ).status_code
        == 403
    )
    expires = int(time.time()) - 1
    sig = signature(settings.secret_key, wid, uuid.UUID(asset["id"]), expires)
    assert client.get(f"{parsed.path}?expires={expires}&signature={sig}").status_code == 403
    with pytest.raises(PublisherError):
        delivery_urls(session, settings, uid, uuid.uuid4(), [asset["download_url"]])
    settings.public_api_base_url = ""
    with pytest.raises(PublisherError, match="PUBLIC_API_BASE_URL"):
        delivery_urls(session, settings, uid, wid, [asset["download_url"]])


def test_publish_now_and_later_preserve_assets_and_are_idempotent(
    client, tmp_path, session, monkeypatch
):
    owner, root, asset, settings = setup_media(client, tmp_path)
    wid, uid = uuid.UUID(owner["workspace"]["id"]), uuid.UUID(owner["user"]["id"])
    account = SocialAccount(
        workspace_id=wid,
        created_by_user_id=uid,
        platform="instagram",
        external_account_id="demo",
        display_name="Demo",
        access_token_ref="test-token",
        status="connected",
    )
    session.add(account)
    session.commit()
    captured = []

    class Publisher(MockSocialPublisher):
        def publish(self, request, *, access_token):
            captured.append(request)
            return super().publish(request, access_token=access_token)

    monkeypatch.setattr(PublishingService, "_publisher", lambda *args: Publisher())
    body = {
        "social_account_id": str(account.id),
        "idempotency_key": "test-now-123",
        "text": "Caption #launch",
        "media_urls": [asset["download_url"]],
    }
    first = client.post(f"{root}/publishing/jobs", headers=bearer(owner), json=body)
    assert first.status_code == 201, first.text
    assert first.json()["status"] == "published"
    assert captured[0].media_urls[0].startswith("https://delivery.example.test/")
    assert (
        client.post(f"{root}/publishing/jobs", headers=bearer(owner), json=body).json()["id"]
        == first.json()["id"]
    )
    assert len(captured) == 1
    body.update(
        idempotency_key="test-later-123",
        scheduled_for=(datetime.now(UTC) + timedelta(days=7)).isoformat(),
    )
    later = client.post(f"{root}/operations/schedule", headers=bearer(owner), json=body)
    assert later.status_code == 201, later.text
    assert later.json()["payload"]["media_urls"] == [asset["download_url"]]
    service = PublishingService(session, settings)
    job = service.publish(
        uid, wid, PublishRequest(**{k: v for k, v in body.items() if k != "scheduled_for"})
    )
    assert job.status == "published"
    assert "signature=" in captured[-1].media_urls[0]
    body["scheduled_for"] = (datetime.now(UTC) - timedelta(days=1)).isoformat()
    assert (
        client.post(f"{root}/operations/schedule", headers=bearer(owner), json=body).status_code
        == 409
    )


def test_due_worker_dispatch_and_explicit_failed_retry(
    client, tmp_path, session, session_factory, monkeypatch
):
    from pathlib import Path

    monkeypatch.syspath_prepend(str(Path(__file__).resolve().parents[3]))
    monkeypatch.setenv("AEVRA_ENABLE_CELERY", "0")
    from services.workers import tasks

    from aevra_api.services.operations import OperationsService

    owner, _, asset, settings = setup_media(client, tmp_path)
    wid, uid = uuid.UUID(owner["workspace"]["id"]), uuid.UUID(owner["user"]["id"])
    account = SocialAccount(
        workspace_id=wid,
        created_by_user_id=uid,
        platform="instagram",
        external_account_id="demo",
        display_name="Demo",
        access_token_ref="test",
        status="connected",
    )
    session.add(account)
    session.flush()
    item = ScheduledPost(
        workspace_id=wid,
        created_by_user_id=uid,
        social_account_id=account.id,
        idempotency_key="worker-test",
        status="scheduled",
        scheduled_for=datetime.now(UTC) - timedelta(minutes=1),
        payload={"text": "Hello #world", "media_urls": [asset["download_url"]]},
    )
    session.add(item)
    session.commit()
    calls = []

    class Publisher(MockSocialPublisher):
        def publish(self, request, *, access_token):
            calls.append(request)
            if len(calls) == 1:
                raise PublisherError("temporary provider failure", retryable=True)
            return super().publish(request, access_token=access_token)

    monkeypatch.setattr(PublishingService, "_publisher", lambda *args: Publisher())
    monkeypatch.setattr(tasks, "SessionLocal", session_factory)
    monkeypatch.setattr(tasks, "get_settings", lambda: settings)
    assert tasks.dispatch_due_posts(None)["processed"] == 1
    session.refresh(item)
    assert item.status == "failed"
    OperationsService(session).retry(uid, wid, item.id)
    assert tasks.dispatch_due_posts(None)["processed"] == 1
    session.refresh(item)
    assert item.status == "published"
    job = session.get(PublishJob, item.published_job_id)
    assert job.attempts == 2
    assert "signature=" in calls[-1].media_urls[0]
    assert tasks.dispatch_due_posts(None)["processed"] == 0
    assert len(calls) == 2
