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
    with TestClient(app) as c:
        yield c


# ── Health ──────────────────────────────────────────────────────────


def test_health(client):
    r = client.get("/health")
    assert r.status_code == 200
    body = r.json()
    assert body["ok"] is True
    assert "vendors" in body
    assert "products" in body


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
    r = client.post("/api/devices/register", json={})
    assert r.status_code == 200
    did = r.json()["deviceId"]

    r2 = client.get(f"/api/devices/{did}/state")
    assert r2.status_code == 200
    body = r2.json()
    assert body["subscription"]["isPremium"] is False
    assert body["subscription"]["checksUsed"] == 0


def test_device_profile(client):
    r = client.post("/api/devices/register", json={})
    did = r.json()["deviceId"]

    r2 = client.put(
        f"/api/devices/{did}/profile",
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
    r = client.post("/api/devices/register", json={})
    did = r.json()["deviceId"]

    # First 3 checks should be allowed
    for _ in range(3):
        rc = client.post(f"/api/devices/{did}/check")
        assert rc.status_code == 200
        assert rc.json()["allowed"] is True

    # 4th check should be blocked
    rc4 = client.post(f"/api/devices/{did}/check")
    assert rc4.status_code == 200
    assert rc4.json()["allowed"] is False


def test_premium_activation(client):
    r = client.post("/api/devices/register", json={})
    did = r.json()["deviceId"]

    token = "USIZO-SINGLE-USE-TEST-TOKEN"
    with db() as conn:
        conn.execute(
            "INSERT INTO activation_tokens (token_hash, reference, created_at) VALUES (?, ?, ?)",
            (token_digest(token), "ECO-TEST-001", utc_now()),
        )

    r2 = client.post(f"/api/devices/{did}/subscriptions/activate", json={"token": token})
    assert r2.status_code == 200
    assert r2.json()["isPremium"] is True

    # Now checks should always be allowed
    for _ in range(5):
        rc = client.post(f"/api/devices/{did}/check")
        assert rc.json()["allowed"] is True

    # A paid token cannot be copied to another device.
    second = client.post("/api/devices/register", json={}).json()["deviceId"]
    reused = client.post(f"/api/devices/{second}/subscriptions/activate", json={"token": token})
    assert reused.status_code == 400


# ── Orders ──────────────────────────────────────────────────────────


def test_order_create(client):
    r = client.post("/api/devices/register", json={})
    did = r.json()["deviceId"]

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
    r = client.post("/api/devices/register", json={})
    did = r.json()["deviceId"]
    r2 = client.post(
        f"/api/devices/{did}/orders",
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
    r = client.post("/api/devices/register", json={})
    did = r.json()["deviceId"]
    client.post(
        f"/api/devices/{did}/orders",
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

    r = client.post("/api/devices/register", json={})
    did = r.json()["deviceId"]
    order = client.post(
        f"/api/devices/{did}/orders",
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
