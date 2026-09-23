"""Basic API tests for the UsizoAI backend."""

import io
import os
import tempfile

import pytest
from fastapi.testclient import TestClient

# Point to a temp database before importing the app
_tmp_db = tempfile.mktemp(suffix=".db")
os.environ["DATABASE_PATH"] = _tmp_db

from app.main import app  # noqa: E402
import app.main as main_module  # noqa: E402
from app.database import db, token_digest, utc_now  # noqa: E402


@pytest.fixture()
def client():
    """Yield a TestClient with lifespan (schema + seed) active."""
    # Rate-limit buckets are class-level state shared across the whole
    # session — reset them so tests cannot starve each other.
    main_module.RateLimitMiddleware._requests.clear()
    with TestClient(app) as c:
        yield c


def _register_device(client):
    """Register a device; return (deviceId, headers carrying its token)."""
    r = client.post("/api/devices/register", json={})
    assert r.status_code == 200
    data = r.json()
    assert data["deviceToken"]
    return data["deviceId"], {"X-Device-Token": data["deviceToken"]}


# ── Health ──────────────────────────────────────────────────────────


def test_health(client):
    r = client.get("/health")
    assert r.status_code == 200
    body = r.json()
    assert body["ok"] is True
    assert "vendors" in body
    assert "products" in body


# ── Android APK download ────────────────────────────────────────────


def test_download_redirects_to_latest_release(client):
    """The download must follow the newest published release, never a pinned tag."""
    r = client.get("/download", follow_redirects=False)
    assert r.status_code == 302
    location = r.headers["location"]
    assert "/releases/latest/download/UsizoAI.apk" in location
    assert "/releases/download/v" not in location


def test_download_returns_503_when_unconfigured(client, monkeypatch):
    monkeypatch.setattr(main_module, "APK_DOWNLOAD_URL", "")
    r = client.get("/download", follow_redirects=False)
    assert r.status_code == 503


# ── App version / update checks ─────────────────────────────────────


def test_parse_version_handles_tags_and_builds():
    assert main_module.parse_version("v1.1.0") == (1, 1, 0)
    assert main_module.parse_version("1.0.0+2") == (1, 0, 0)
    assert main_module.parse_version("1.2") == (1, 2, 0)
    assert main_module.parse_version("1.10.0") > main_module.parse_version("1.9.0")
    assert main_module.parse_version("not-a-version") is None


def _release_stub():
    return {
        "source": "github",
        "version": "1.1.0",
        "tag": "v1.1.0",
        "publishedAt": "2026-09-22T05:47:47Z",
        "notes": "Latest release",
        "sizeBytes": 129306624,
        "downloadUrl": "https://example.test/UsizoAI.apk",
    }


def test_app_version_reports_available_update(client, monkeypatch):
    monkeypatch.setattr(main_module, "latest_apk_release", _release_stub)
    r = client.get("/api/app/version?currentVersion=1.0.0")
    assert r.status_code == 200
    body = r.json()
    assert body["latestVersion"] == "1.1.0"
    assert body["latestTag"] == "v1.1.0"
    assert body["source"] == "github"
    assert body["updateAvailable"] is True
    assert body["updateRequired"] is False
    assert body["downloadUrl"] == "https://example.test/UsizoAI.apk"
    assert body["sizeBytes"] == 129306624


def test_app_version_is_up_to_date(client, monkeypatch):
    monkeypatch.setattr(main_module, "latest_apk_release", _release_stub)
    for version in ("1.1.0", "1.1.0+2", "1.1.0%2B2", "1.1.0 2"):
        body = client.get(f"/api/app/version?currentVersion={version}").json()
        assert body["updateAvailable"] is False, version
        assert body["currentVersion"] is not None


def test_app_version_available_without_current_version(client, monkeypatch):
    monkeypatch.setattr(main_module, "latest_apk_release", _release_stub)
    body = client.get("/api/app/version").json()
    assert body["currentVersion"] is None
    assert body["updateAvailable"] is False


def test_app_version_requires_update_below_minimum(client, monkeypatch):
    monkeypatch.setattr(
        main_module,
        "latest_apk_release",
        lambda: {"version": "1.2.0", "tag": "v1.2.0"},
    )
    monkeypatch.setattr(main_module, "APP_MINIMUM_VERSION", "1.1.0")
    body = client.get("/api/app/version?currentVersion=1.0.0").json()
    assert body["updateAvailable"] is True
    assert body["updateRequired"] is True
    assert body["minimumVersion"] == "1.1.0"


def test_app_version_unavailable_without_release(client, monkeypatch):
    monkeypatch.setattr(main_module, "latest_apk_release", lambda: None)
    monkeypatch.setattr(main_module, "APP_LATEST_VERSION", "")
    r = client.get("/api/app/version")
    assert r.status_code == 503


def test_app_version_uses_env_fallback(client, monkeypatch):
    monkeypatch.setattr(main_module, "latest_apk_release", lambda: None)
    monkeypatch.setattr(main_module, "APP_LATEST_VERSION", "2.0.0")
    body = client.get("/api/app/version?currentVersion=1.1.0").json()
    assert body["latestVersion"] == "2.0.0"
    assert body["latestTag"] == "v2.0.0"
    assert body["source"] == "static"
    assert body["updateAvailable"] is True


def test_latest_release_falls_back_to_feed(client, monkeypatch):
    """A rate-limited GitHub API must not break version checks."""
    monkeypatch.setattr(main_module, "_APK_RELEASE_CACHE", {"at": 0.0, "payload": None})

    def _boom():
        raise RuntimeError("API rate limit exceeded")

    monkeypatch.setattr(main_module, "_release_from_api", _boom)
    monkeypatch.setattr(
        main_module,
        "_release_from_atom",
        lambda: {
            "source": "atom",
            "version": "1.1.0",
            "tag": "v1.1.0",
            "publishedAt": "2026-09-22T05:47:47Z",
            "notes": "",
            "sizeBytes": None,
            "downloadUrl": "https://example.test/UsizoAI.apk",
        },
    )
    release = main_module.latest_apk_release()
    assert release["source"] == "atom"
    assert release["version"] == "1.1.0"
    body = client.get("/api/app/version?currentVersion=1.0.0").json()
    assert body["source"] == "atom"
    assert body["updateAvailable"] is True


def test_latest_release_returns_none_when_every_source_fails(client, monkeypatch):
    monkeypatch.setattr(main_module, "_APK_RELEASE_CACHE", {"at": 0.0, "payload": None})

    def _boom():
        raise RuntimeError("network unavailable")

    monkeypatch.setattr(main_module, "_release_from_api", _boom)
    monkeypatch.setattr(main_module, "_release_from_atom", _boom)
    assert main_module.latest_apk_release() is None
    monkeypatch.setattr(main_module, "APP_LATEST_VERSION", "")
    assert client.get("/api/app/version").status_code == 503


def test_release_tag_pattern_ignores_pre_releases():
    assert main_module.RELEASE_TAG_PATTERN.fullmatch("v1.1.0")
    assert main_module.RELEASE_TAG_PATTERN.fullmatch("1.2")
    assert not main_module.RELEASE_TAG_PATTERN.fullmatch("v1.2.0-rc1")
    assert not main_module.RELEASE_TAG_PATTERN.fullmatch("latest")


def test_account_register_and_login(client):
    response = client.post(
        "/api/auth/register",
        json={
            "name": "Test User",
            "email": "account@example.com",
            "password": "strong-password",
            "allergies": "Peanuts",
            "emergencyContact": "+254700000000",
        },
    )
    assert response.status_code == 200
    assert response.json()["token"]
    assert response.json()["account"]["name"] == "Test User"

    duplicate = client.post(
        "/api/auth/register",
        json={
            "name": "Other User",
            "email": "account@example.com",
            "password": "strong-password",
        },
    )
    assert duplicate.status_code == 409

    login = client.post(
        "/api/auth/login",
        json={"identifier": "account@example.com", "password": "strong-password"},
    )
    assert login.status_code == 200
    me = client.get(
        "/api/auth/me",
        headers={"Authorization": f"Bearer {login.json()['token']}"},
    )
    assert me.status_code == 200
    assert me.json()["account"]["allergies"] == "Peanuts"


def test_auth_rate_limit_returns_retry_after(client):
    headers = {"X-Forwarded-For": "198.51.100.42"}
    for _ in range(10):
        response = client.post("/api/auth/login", headers=headers, json={})
        assert response.status_code == 422
    limited = client.post("/api/auth/login", headers=headers, json={})
    assert limited.status_code == 429
    assert limited.headers["retry-after"]


# ── Catalog (public) ────────────────────────────────────────────────


def test_list_vendors_starts_empty(client):
    r = client.get("/api/catalog/vendors")
    assert r.status_code == 200
    vendors = r.json()["vendors"]
    assert isinstance(vendors, list)
    assert vendors == []


def test_list_products_starts_empty(client):
    r = client.get("/api/catalog/products")
    assert r.status_code == 200
    products = r.json()["products"]
    assert isinstance(products, list)
    assert products == []


def test_list_products_by_vendor(client):
    r = client.get("/api/catalog/products?vendorId=missing-vendor")
    assert r.status_code == 200
    assert r.json()["products"] == []


def test_remedy_submission_requires_moderation(client):
    device_id = client.post("/api/devices/register", json={}).json()["deviceId"]
    payload = {
        "deviceId": device_id,
        "name": "Test herb",
        "category": "Digestive wellness",
        "description": "A community food suggestion for occasional discomfort.",
        "usage": "Use only as supportive information and seek care when needed.",
        "preparation": "Prepare with clean water according to qualified guidance.",
        "dosage": "No universal dose; ask a healthcare worker.",
        "warning": "Do not use during pregnancy or with medicines without advice.",
        "evidenceSource": "Community reference and clinician review pending",
        "tags": ["digestive"],
    }
    submitted = client.post("/api/remedy-submissions", json=payload)
    assert submitted.status_code == 200
    assert submitted.json()["status"] == "pending"
    assert client.get("/api/catalog/remedies").json()["remedies"] == []


def test_admin_can_approve_remedy_submission(client, monkeypatch):
    monkeypatch.setattr(main_module, "ADMIN_TOKEN", "test-admin-token")
    device_id = client.post("/api/devices/register", json={}).json()["deviceId"]
    payload = {
        "deviceId": device_id,
        "name": "Approved herb",
        "category": "General wellness",
        "description": "A carefully documented community wellness suggestion.",
        "usage": "Use as supportive information and consult a healthcare worker.",
        "preparation": "Prepare safely with clean equipment and water.",
        "dosage": "No universal dose; follow professional guidance.",
        "warning": "Stop if symptoms worsen and seek professional care.",
        "evidenceSource": "Published reference for moderation test",
    }
    submission_id = client.post("/api/remedy-submissions", json=payload).json()["submissionId"]
    response = client.patch(
        f"/api/admin/remedy-submissions/{submission_id}",
        json={"action": "approve", "moderationNote": "Reviewed"},
        headers={"Authorization": f"Bearer {main_module.ADMIN_TOKEN}"},
    )
    assert response.status_code == 200
    remedies = client.get("/api/catalog/remedies").json()["remedies"]
    assert remedies[0]["name"] == "Approved herb"


# ── Sync ────────────────────────────────────────────────────────────


def test_full_catalog_sync(client):
    r = client.get("/api/sync/full-catalog")
    assert r.status_code == 200
    body = r.json()
    assert "vendors" in body
    assert "products" in body
    assert "serverTime" in body


def test_incremental_sync(client):
    r = client.get("/api/sync/catalog?since=1970-01-01T00:00:00.000Z")
    assert r.status_code == 200
    body = r.json()
    assert "vendors" in body
    assert "deletedProductIds" in body


# ── Vendor auth ─────────────────────────────────────────────────────


def test_vendor_register_and_login(client):
    r = client.post(
        "/api/vendors/register",
        json={
            "businessName": "Test Shop",
            "location": "Nairobi",
            "phone": "+254700000001",
            "pin": "5678",
        },
    )
    assert r.status_code == 200
    token = r.json()["token"]
    assert token

    r2 = client.post(
        "/api/vendors/login",
        json={"phone": "+254700000001", "pin": "5678"},
    )
    assert r2.status_code == 200
    assert r2.json()["token"]


def test_vendor_register_duplicate_phone(client):
    client.post(
        "/api/vendors/register",
        json={
            "businessName": "Dup Shop",
            "location": "Mombasa",
            "phone": "+254700000099",
            "pin": "1234",
        },
    )
    r = client.post(
        "/api/vendors/register",
        json={
            "businessName": "Dup Shop 2",
            "location": "Mombasa",
            "phone": "+254700000099",
            "pin": "5678",
        },
    )
    assert r.status_code == 409


def test_vendor_login_wrong_pin(client):
    r = client.post(
        "/api/vendors/login",
        json={"phone": "+254700000001", "pin": "0000"},
    )
    assert r.status_code == 401


# ── Vendor profile & products (authenticated) ───────────────────────


def _auth_header(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def test_vendor_me_and_update(client):
    reg = client.post(
        "/api/vendors/register",
        json={
            "businessName": "Profile Shop",
            "location": "Kisumu",
            "phone": "+254700000002",
            "pin": "1234",
        },
    )
    token = reg.json()["token"]
    headers = _auth_header(token)

    r = client.get("/api/vendors/me", headers=headers)
    assert r.status_code == 200
    assert r.json()["vendor"]["name"] == "Profile Shop"

    r2 = client.patch(
        "/api/vendors/me",
        json={"name": "Updated Shop"},
        headers=headers,
    )
    assert r2.status_code == 200
    assert r2.json()["vendor"]["name"] == "Updated Shop"


def test_product_crud(client):
    reg = client.post(
        "/api/vendors/register",
        json={
            "businessName": "Product Shop",
            "location": "Nakuru",
            "phone": "+254700000003",
            "pin": "1234",
        },
    )
    token = reg.json()["token"]
    headers = _auth_header(token)

    # Create
    r = client.post(
        "/api/vendors/me/products",
        json={
            "name": "Moringa Powder",
            "priceCents": 1500,
            "category": "Herbal remedy",
        },
        headers=headers,
    )
    assert r.status_code == 200
    pid = r.json()["product"]["id"]

    # List
    r2 = client.get("/api/vendors/me/products", headers=headers)
    assert r2.status_code == 200
    assert any(p["id"] == pid for p in r2.json()["products"])

    # Update
    r3 = client.patch(
        f"/api/vendors/me/products/{pid}",
        json={"priceCents": 2000},
        headers=headers,
    )
    assert r3.status_code == 200
    assert r3.json()["product"]["priceCents"] == 2000

    # Delete
    r4 = client.delete(f"/api/vendors/me/products/{pid}", headers=headers)
    assert r4.status_code == 200

    # Verify deleted from list
    r5 = client.get("/api/vendors/me/products", headers=headers)
    assert not any(p["id"] == pid for p in r5.json()["products"])


# ── Device & subscription ───────────────────────────────────────────


def test_device_register_and_state(client):
    did, device_headers = _register_device(client)

    r2 = client.get(f"/api/devices/{did}/state", headers=device_headers)
    assert r2.status_code == 200
    body = r2.json()
    assert body["subscription"]["isPremium"] is False
    assert body["subscription"]["checksUsed"] == 0


def test_device_profile(client):
    did, device_headers = _register_device(client)

    r2 = client.put(
        f"/api/devices/{did}/profile",
        headers=device_headers,
        json={
            "name": "Test User",
            "email": "test@example.com",
            "allergies": "Peanuts",
            "emergencyContact": "+254700000999",
        },
    )
    assert r2.status_code == 200
    assert r2.json()["profile"]["name"] == "Test User"


def test_device_check_rate_limit(client):
    did, device_headers = _register_device(client)

    # First 3 checks should be allowed
    for _ in range(3):
        rc = client.post(f"/api/devices/{did}/check", headers=device_headers)
        assert rc.status_code == 200
        assert rc.json()["allowed"] is True

    # 4th check should be blocked
    rc4 = client.post(f"/api/devices/{did}/check", headers=device_headers)
    assert rc4.status_code == 200
    assert rc4.json()["allowed"] is False


def test_premium_activation(client):
    did, device_headers = _register_device(client)

    token = "USIZO-SINGLE-USE-TEST-TOKEN"
    with db() as conn:
        conn.execute(
            "INSERT INTO activation_tokens (token_hash, reference, created_at) VALUES (?, ?, ?)",
            (token_digest(token), "ECO-TEST-001", utc_now()),
        )

    r2 = client.post(
        f"/api/devices/{did}/subscriptions/activate",
        headers=device_headers,
        json={"token": token},
    )
    assert r2.status_code == 200
    assert r2.json()["isPremium"] is True

    # Now checks should always be allowed
    for _ in range(5):
        rc = client.post(f"/api/devices/{did}/check", headers=device_headers)
        assert rc.json()["allowed"] is True

    # A paid token cannot be copied to another device.
    second, second_headers = _register_device(client)
    reused = client.post(
        f"/api/devices/{second}/subscriptions/activate",
        headers=second_headers,
        json={"token": token},
    )
    assert reused.status_code == 400


# ── Orders ──────────────────────────────────────────────────────────


def test_order_create(client):
    did, device_headers = _register_device(client)

    vendor = client.post(
        "/api/vendors/register",
        json={
            "businessName": "Order Shop",
            "location": "Bulawayo",
            "phone": "+263780000001",
            "pin": "1234",
        },
    ).json()
    product = client.post(
        "/api/vendors/me/products",
        json={"name": "Herbal tea", "priceCents": 3100},
        headers=_auth_header(vendor["token"]),
    ).json()["product"]

    r2 = client.post(
        f"/api/devices/{did}/orders",
        headers=device_headers,
        json={
            "vendorId": vendor["vendor"]["id"],
            "totalCents": 1,  # Must be ignored by the server.
            "items": [
                {
                    "productId": product["id"],
                    "name": "forged",
                    "priceCents": 1,
                    "quantity": 1,
                }
            ],
        },
    )
    assert r2.status_code == 200
    assert r2.json()["order"]["id"]
    assert r2.json()["order"]["totalCents"] == 3100


def test_vendor_order_update(client):
    # Register vendor
    reg = client.post(
        "/api/vendors/register",
        json={
            "businessName": "Order Shop",
            "location": "Eldoret",
            "phone": "+254700000004",
            "pin": "1234",
        },
    )
    token = reg.json()["token"]
    headers = _auth_header(token)
    vid = reg.json()["vendor"]["id"]

    product = client.post(
        "/api/vendors/me/products",
        json={"name": "Stuff", "priceCents": 3000},
        headers=headers,
    ).json()["product"]

    # Create device + order
    did, device_headers = _register_device(client)
    r2 = client.post(
        f"/api/devices/{did}/orders",
        headers=device_headers,
        json={
            "vendorId": vid,
            "totalCents": 3000,
            "items": [{"productId": product["id"], "quantity": 1}],
        },
    )
    oid = r2.json()["order"]["id"]

    # Vendor marks confirmed
    r3 = client.patch(
        f"/api/vendors/me/orders/{oid}",
        json={"status": "confirmed"},
        headers=headers,
    )
    assert r3.status_code == 200
    assert r3.json()["order"]["status"] == "confirmed"

    # Vendor marks delivered
    r4 = client.patch(
        f"/api/vendors/me/orders/{oid}",
        json={"status": "delivered"},
        headers=headers,
    )
    assert r4.status_code == 200
    assert r4.json()["order"]["status"] == "delivered"


def test_vendor_orders_list(client):
    # Register vendor
    reg = client.post(
        "/api/vendors/register",
        json={
            "businessName": "List Order Shop",
            "location": "Meru",
            "phone": "+254700000008",
            "pin": "1234",
        },
    )
    token = reg.json()["token"]
    headers = _auth_header(token)
    vid = reg.json()["vendor"]["id"]

    product = client.post(
        "/api/vendors/me/products",
        json={"name": "Tea", "priceCents": 2000},
        headers=headers,
    ).json()["product"]

    # Create device + order
    did, device_headers = _register_device(client)
    client.post(
        f"/api/devices/{did}/orders",
        headers=device_headers,
        json={
            "vendorId": vid,
            "totalCents": 2000,
            "items": [{"productId": product["id"], "quantity": 1}],
        },
    )

    r2 = client.get("/api/vendors/me/orders", headers=headers)
    assert r2.status_code == 200
    orders = r2.json()["orders"]
    assert len(orders) >= 1
    assert orders[0]["vendorId"] == vid
    # The customer's device id is a credential and must not leak to vendors.
    assert "deviceId" not in orders[0]


def test_production_supplier_seed_repairs_legacy_row(client):
    """Seed repair normalizes the spaced phone and resets the PIN to 1234."""
    import app.main as main_module

    # Simulate a legacy row: phone stored with spaces and a stale hash.
    with db() as conn:
        conn.execute(
            """
            INSERT INTO vendors (
              id, name, location, description, phone, whatsapp,
              ecocash_number, rating, review_count, pin_hash, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, 0, 0, ?, ?, ?)
            """,
            (
                "vendor-legacy-seed",
                "Old Row",
                "Bulawayo",
                "Legacy seeded supplier.",
                "+263 780747989",
                "+263 780747989",
                "+263 780747989",
                "$2b$12$invalidinvalidinvalidinvalidinvalidinvalidinvalidinvalidiu",
                utc_now(),
                utc_now(),
            ),
        )

    main_module._ensure_production_supplier()

    r = client.post(
        "/api/vendors/login",
        json={"phone": "+263 780747989", "pin": "1234"},
    )
    assert r.status_code == 200
    assert r.json()["vendor"]["name"] == "Treasure Motsu"

    # A missing row is re-inserted with the same normalized phone and PIN.
    with db() as conn:
        conn.execute("DELETE FROM vendors WHERE phone = ?", ("+263780747989",))
    main_module._ensure_production_supplier()
    r = client.post(
        "/api/vendors/login",
        json={"phone": "+263780747989", "pin": "1234"},
    )
    assert r.status_code == 200
    assert r.json()["vendor"]["name"] == "Treasure Motsu"


def test_vendor_payment_proof_review_flow(client):
    """Vendor can view and approve/reject a buyer's uploaded payment proof."""
    reg = client.post(
        "/api/vendors/register",
        json={
            "businessName": "Proof Shop",
            "location": "Kisumu",
            "phone": "+254700000010",
            "pin": "1234",
        },
    )
    token = reg.json()["token"]
    headers = _auth_header(token)
    vid = reg.json()["vendor"]["id"]

    product = client.post(
        "/api/vendors/me/products",
        json={"name": "Honey", "priceCents": 3000},
        headers=headers,
    ).json()["product"]

    did, device_headers = _register_device(client)
    order = client.post(
        f"/api/devices/{did}/orders",
        headers=device_headers,
        json={
            "vendorId": vid,
            "totalCents": 3000,
            "items": [{"productId": product["id"], "quantity": 1}],
        },
    ).json()["order"]
    order_id = order["id"]

    # No proof uploaded yet.
    assert client.get(
        f"/api/vendors/me/orders/{order_id}/payment-proof", headers=headers
    ).status_code == 404

    # Upload a proof image as the buyer.
    png = b"\x89PNG\r\n\x1a\n" + b"0" * 64
    upload = client.post(
        f"/api/orders/{order_id}/payment-proof",
        files={"file": ("proof.png", io.BytesIO(png), "image/png")},
        headers={"X-Device-Id": did},
    )
    assert upload.status_code == 200

    # Vendor can view it and confirm the payment.
    view = client.get(
        f"/api/vendors/me/orders/{order_id}/payment-proof", headers=headers
    )
    assert view.status_code == 200
    assert view.headers["content-type"].startswith("image/png")

    review = client.post(
        f"/api/vendors/me/orders/{order_id}/payment-proof",
        json={"status": "confirmed"},
        headers=headers,
    )
    assert review.status_code == 200
    assert review.json()["order"]["status"] == "confirmed"


# ── Reviews ─────────────────────────────────────────────────────


def test_create_review(client):
    vendors = client.get("/api/catalog/vendors").json()["vendors"]
    vid = vendors[0]["id"]

    r = client.post(
        "/api/reviews",
        json={
            "vendorId": vid,
            "rating": 5,
            "comment": "Great products!",
            "deviceId": "test-device-001",
        },
    )
    assert r.status_code == 200
    assert r.json()["review"]["rating"] == 5


def test_review_duplicate_prevented(client):
    vendors = client.get("/api/catalog/vendors").json()["vendors"]
    vid = vendors[0]["id"]

    r = client.post(
        "/api/reviews",
        json={
            "vendorId": vid,
            "rating": 4,
            "comment": "Good",
            "deviceId": "test-device-dup",
        },
    )
    assert r.status_code == 200

    r2 = client.post(
        "/api/reviews",
        json={
            "vendorId": vid,
            "rating": 3,
            "comment": "OK",
            "deviceId": "test-device-dup",
        },
    )
    assert r2.status_code == 409


def test_list_vendor_reviews(client):
    vendors = client.get("/api/catalog/vendors").json()["vendors"]
    vid = vendors[0]["id"]

    r = client.get(f"/api/vendors/{vid}/reviews")
    assert r.status_code == 200
    assert isinstance(r.json()["reviews"], list)


# ── Image upload ────────────────────────────────────────────────────


def test_product_image_upload(client):
    reg = client.post(
        "/api/vendors/register",
        json={
            "businessName": "Image Shop",
            "location": "Thika",
            "phone": "+254700000005",
            "pin": "1234",
        },
    )
    token = reg.json()["token"]
    headers = _auth_header(token)

    # Create product
    r = client.post(
        "/api/vendors/me/products",
        json={"name": "Photo Herb", "priceCents": 1000},
        headers=headers,
    )
    pid = r.json()["product"]["id"]

    # Create a minimal valid PNG (1x1 red pixel)
    import struct
    import zlib

    def make_tiny_png() -> bytes:
        sig = b"\x89PNG\r\n\x1a\n"

        def chunk(ctype: bytes, data: bytes) -> bytes:
            c = ctype + data
            return (
                struct.pack(">I", len(data))
                + c
                + struct.pack(">I", zlib.crc32(c) & 0xFFFFFFFF)
            )

        ihdr = struct.pack(">IIBBBBB", 1, 1, 8, 2, 0, 0, 0)
        raw = b"\x00\x00\x00\x00\x00"  # filter byte + RGB
        idat = zlib.compress(raw)
        return sig + chunk(b"IHDR", ihdr) + chunk(b"IDAT", idat) + chunk(b"IEND", b"")

    img = make_tiny_png()
    r2 = client.post(
        f"/api/products/{pid}/image",
        files={"file": ("test.png", io.BytesIO(img), "image/png")},
        headers=headers,
    )
    assert r2.status_code == 200
    asset = r2.json()["imageAsset"]
    assert asset.startswith("/uploads/")

    # Serve the image
    r3 = client.get(asset)
    assert r3.status_code == 200


def test_image_upload_bad_type(client):
    reg = client.post(
        "/api/vendors/register",
        json={
            "businessName": "Bad Image Shop",
            "location": "Nyeri",
            "phone": "+254700000006",
            "pin": "1234",
        },
    )
    token = reg.json()["token"]
    headers = _auth_header(token)

    r = client.post(
        "/api/vendors/me/products",
        json={"name": "Bad Image", "priceCents": 500},
        headers=headers,
    )
    pid = r.json()["product"]["id"]

    r2 = client.post(
        f"/api/products/{pid}/image",
        files={"file": ("test.exe", io.BytesIO(b"MZ fake"), "application/octet-stream")},
        headers=headers,
    )
    assert r2.status_code == 400


# ── Security: device authentication & rate limiting ───────────────────


def test_device_endpoints_require_token(client):
    """A device id alone must not grant access to medical data or actions."""
    did, _ = _register_device(client)

    # No token presented.
    assert client.get(f"/api/devices/{did}/state").status_code == 401
    assert client.put(f"/api/devices/{did}/profile", json={}).status_code == 401
    assert client.post(f"/api/devices/{did}/check").status_code == 401
    assert (
        client.post(
            f"/api/devices/{did}/subscriptions/activate",
            json={"token": "USIZO-NOPE"},
        ).status_code
        == 401
    )
    assert (
        client.post(
            f"/api/devices/{did}/orders",
            json={"vendorId": "v", "items": [{"productId": "p", "quantity": 1}]},
        ).status_code
        == 401
    )
    assert (
        client.post(
            f"/api/devices/{did}/plus-payment-submissions",
            json={
                "merchantReference": "ECO-99999",
                "confirmationMessage": "Paid via EcoCash",
                "deliveryEmail": "buyer@example.com",
            },
        ).status_code
        == 401
    )

    # A forged token is rejected too.
    forged = {"X-Device-Token": "not-the-real-token"}
    assert client.get(f"/api/devices/{did}/state", headers=forged).status_code == 401

    # Unknown device ids are indistinguishable from bad credentials.
    assert (
        client.get(
            "/api/devices/does-not-exist/state",
            headers={"X-Device-Token": "whatever"},
        ).status_code
        == 401
    )


def test_device_reregistration_requires_token(client):
    """Knowing a leaked device id must not let an attacker claim it."""
    did, device_headers = _register_device(client)

    stolen = client.post("/api/devices/register", json={"deviceId": did})
    assert stolen.status_code == 403

    wrong = client.post(
        "/api/devices/register",
        json={"deviceId": did},
        headers={"X-Device-Token": "forged-token"},
    )
    assert wrong.status_code == 403

    owner = client.post(
        "/api/devices/register",
        json={"deviceId": did},
        headers=device_headers,
    )
    assert owner.status_code == 200
    assert owner.json()["deviceId"] == did
    assert owner.json()["deviceToken"] == device_headers["X-Device-Token"]

    # And the stolen id still cannot read the device state.
    assert client.get(f"/api/devices/{did}/state").status_code == 401


def test_legacy_device_without_token_hash_is_locked(client):
    """Devices that predate token issuance cannot be accessed or claimed."""
    now = utc_now()
    with db() as conn:
        conn.execute(
            "INSERT INTO devices (id, created_at, updated_at) VALUES (?, ?, ?)",
            ("legacy-device", now, now),
        )
        conn.execute(
            "INSERT INTO device_profiles (device_id, updated_at) VALUES (?, ?)",
            ("legacy-device", now),
        )
        conn.execute(
            "INSERT INTO subscriptions (device_id, is_premium, checks_used, updated_at) VALUES (?, 0, 0, ?)",
            ("legacy-device", now),
        )

    assert client.get("/api/devices/legacy-device/state").status_code == 401
    claim = client.post("/api/devices/register", json={"deviceId": "legacy-device"})
    assert claim.status_code == 403


def test_rate_limit_uses_last_forwarded_for(client):
    """Rotating spoofed prefixes must not mint fresh buckets: only the
    proxy-appended (last) X-Forwarded-For entry is trusted."""
    for i in range(10):
        spoofed = {"X-Forwarded-For": f"203.0.113.{i}, 198.51.100.99"}
        response = client.post("/api/auth/login", headers=spoofed, json={})
        assert response.status_code == 422

    limited = client.post(
        "/api/auth/login",
        headers={"X-Forwarded-For": "198.0.2.123, 198.51.100.99"},
        json={},
    )
    assert limited.status_code == 429
    assert limited.headers["retry-after"]

    # A different trusted hop still has its own bucket.
    other = client.post(
        "/api/auth/login",
        headers={"X-Forwarded-For": "198.51.100.77"},
        json={},
    )
    assert other.status_code == 422


def test_admin_login_rate_limited(client, monkeypatch):
    """Credential endpoints share the strict auth bucket."""
    monkeypatch.setattr(main_module, "ADMIN_TOKEN", "a" * 40)
    body = {"token": "wrong-token"}
    for _ in range(10):
        assert client.post("/api/admin/login", json=body).status_code == 401
    assert client.post("/api/admin/login", json=body).status_code == 429


def test_vendor_login_rate_limited(client, monkeypatch):
    monkeypatch.setattr(main_module, "RATE_LIMIT_AUTH", 2)
    body = {"phone": "+263780000999", "pin": "0000"}
    for _ in range(2):
        assert client.post("/api/vendors/login", json=body).status_code == 401
    assert client.post("/api/vendors/login", json=body).status_code == 429


def test_production_requires_explicit_supplier_pin(monkeypatch):
    """Production must refuse the placeholder supplier PIN."""
    monkeypatch.setattr(main_module, "ENVIRONMENT", "production")
    monkeypatch.delenv("SEED_SUPPLIER_PIN", raising=False)
    with pytest.raises(RuntimeError, match="SEED_SUPPLIER_PIN must be set"):
        main_module._ensure_production_supplier()

    # An empty value is rejected too, not silently defaulted.
    monkeypatch.setenv("SEED_SUPPLIER_PIN", "")
    with pytest.raises(RuntimeError, match="SEED_SUPPLIER_PIN must be set"):
        main_module._ensure_production_supplier()
