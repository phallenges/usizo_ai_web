import json
import logging
import os
import re
import uuid
from contextlib import asynccontextmanager
from pathlib import Path
from typing import Optional

import bcrypt
import jwt
from dotenv import load_dotenv
from fastapi import Depends, FastAPI, File, Header, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from pydantic import BaseModel, Field
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request

from .database import db, init_schema, row_to_product, row_to_vendor, utc_now
from .seed import new_order_id, new_product_id, new_review_id, new_vendor_id, seed_if_empty

logger = logging.getLogger("usizo")
UPLOAD_DIR = Path(__file__).parent.parent / "data" / "uploads"
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)

load_dotenv()

JWT_SECRET = os.getenv("JWT_SECRET", "usizo-dev-secret-change-me")
JWT_ALG = "HS256"


@asynccontextmanager
async def lifespan(app: FastAPI):
    init_schema()
    seed_if_empty()
    yield


app = FastAPI(title="UsizoAI API", version="1.0.0", lifespan=lifespan)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class LoggingMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        method = request.method
        path = request.url.path
        logger.info(">> %s %s", method, path)
        response = await call_next(request)
        logger.info("<< %s %s -> %d", method, path, response.status_code)
        return response


app.add_middleware(LoggingMiddleware)


def normalize_phone(phone: str) -> str:
    return re.sub(r"[^0-9+]", "", phone or "")


def sign_vendor_token(vendor_id: str) -> str:
    return jwt.encode(
        {"vendorId": vendor_id, "role": "vendor"},
        JWT_SECRET,
        algorithm=JWT_ALG,
    )


def get_vendor_id(authorization: Optional[str] = Header(default=None)) -> str:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Authentication required.")
    token = authorization[7:]
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALG])
    except jwt.PyJWTError as exc:
        raise HTTPException(status_code=401, detail="Invalid or expired token.") from exc
    if payload.get("role") != "vendor" or not payload.get("vendorId"):
        raise HTTPException(status_code=401, detail="Invalid vendor token.")
    return payload["vendorId"]


def is_valid_token(token: str) -> bool:
    prefix = "USIZO-"
    clean = (token or "").strip().upper()
    if not clean.startswith(prefix):
        return False
    body = clean[len(prefix) :]
    if len(body) != 8:
        return False
    data, check = body[:6], body[6:8]
    secret = "USIZOAI2026"
    hash_val = 0
    for ch in data:
        hash_val = ((hash_val << 5) + hash_val + ord(ch)) & 0xFF
    for ch in secret:
        hash_val = ((hash_val << 3) + hash_val + ord(ch)) & 0xFF
    expected = format(hash_val, "02X")
    return check == expected


def ensure_device(device_id: str) -> None:
    with db() as conn:
        row = conn.execute("SELECT id FROM devices WHERE id = ?", (device_id,)).fetchone()
        if row:
            return
        now = utc_now()
        conn.execute(
            "INSERT INTO devices (id, created_at, updated_at) VALUES (?, ?, ?)",
            (device_id, now, now),
        )
        conn.execute(
            "INSERT INTO device_profiles (device_id, updated_at) VALUES (?, ?)",
            (device_id, now),
        )
        conn.execute(
            "INSERT INTO subscriptions (device_id, is_premium, checks_used, updated_at) VALUES (?, 0, 0, ?)",
            (device_id, now),
        )


class VendorRegisterBody(BaseModel):
    businessName: str
    location: str
    phone: str
    pin: str
    whatsapp: str = ""
    description: str = ""


class VendorLoginBody(BaseModel):
    phone: str
    pin: str


class VendorUpdateBody(BaseModel):
    name: Optional[str] = None
    location: Optional[str] = None
    description: Optional[str] = None
    phone: Optional[str] = None
    whatsapp: Optional[str] = None


class ProductBody(BaseModel):
    name: str
    description: str = ""
    category: str = "Herbal remedy"
    priceCents: int
    tags: list[str] = Field(default_factory=list)
    inStock: bool = True
    canBuyOnline: bool = False
    imageAsset: Optional[str] = None


class ProductUpdateBody(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    category: Optional[str] = None
    priceCents: Optional[int] = None
    tags: Optional[list[str]] = None
    inStock: Optional[bool] = None
    canBuyOnline: Optional[bool] = None


class DeviceRegisterBody(BaseModel):
    deviceId: Optional[str] = None


class ProfileBody(BaseModel):
    name: str = ""
    email: str = ""
    allergies: str = ""
    emergencyContact: str = ""


class ActivateBody(BaseModel):
    token: str


class OrderBody(BaseModel):
    id: Optional[str] = None
    vendorId: str
    reference: Optional[str] = None
    totalCents: int
    items: list[dict]
    status: str = "pending"


class ReviewBody(BaseModel):
    vendorId: str
    rating: int = Field(ge=1, le=5)
    comment: str = ""
    deviceId: str


class OrderStatusBody(BaseModel):
    status: str


@app.get("/health")
def health():
    with db() as conn:
        vendors = conn.execute("SELECT COUNT(*) FROM vendors").fetchone()[0]
        products = conn.execute(
            "SELECT COUNT(*) FROM products WHERE deleted_at IS NULL"
        ).fetchone()[0]
    return {
        "ok": True,
        "vendors": vendors,
        "products": products,
        "serverTime": utc_now(),
    }


@app.post("/api/vendors/register")
def vendor_register(body: VendorRegisterBody):
    if not body.businessName.strip():
        raise HTTPException(status_code=400, detail="Business name is required.")
    if not body.location.strip():
        raise HTTPException(status_code=400, detail="Location is required.")
    if not body.phone.strip():
        raise HTTPException(status_code=400, detail="Phone number is required.")
    if len(body.pin) < 4:
        raise HTTPException(status_code=400, detail="PIN must be at least 4 digits.")

    normalized = normalize_phone(body.phone)
    with db() as conn:
        existing = conn.execute(
            "SELECT id FROM vendors WHERE phone = ? OR phone = ?",
            (body.phone.strip(), normalized),
        ).fetchone()
        if existing:
            raise HTTPException(status_code=409, detail="Phone number already registered.")

        vendor_id = new_vendor_id()
        now = utc_now()
        pin_hash = bcrypt.hashpw(body.pin.encode(), bcrypt.gensalt()).decode()
        conn.execute(
            """
            INSERT INTO vendors (
              id, name, location, description, phone, whatsapp,
              rating, review_count, pin_hash, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, 0, 0, ?, ?, ?)
            """,
            (
                vendor_id,
                body.businessName.strip(),
                body.location.strip(),
                body.description.strip(),
                body.phone.strip(),
                body.whatsapp.strip() or body.phone.strip(),
                pin_hash,
                now,
                now,
            ),
        )
        row = conn.execute("SELECT * FROM vendors WHERE id = ?", (vendor_id,)).fetchone()

    return {"vendor": row_to_vendor(row), "token": sign_vendor_token(vendor_id)}


@app.post("/api/vendors/login")
def vendor_login(body: VendorLoginBody):
    normalized = normalize_phone(body.phone)
    with db() as conn:
        row = conn.execute(
            "SELECT * FROM vendors WHERE phone = ? OR phone = ?",
            (body.phone.strip(), normalized),
        ).fetchone()
        if not row or not bcrypt.checkpw(body.pin.encode(), row["pin_hash"].encode()):
            raise HTTPException(status_code=401, detail="Invalid phone number or PIN.")
        vendor_id = row["id"]

    return {"vendor": row_to_vendor(row), "token": sign_vendor_token(vendor_id)}


@app.get("/api/vendors/me")
def vendor_me(vendor_id: str = Depends(get_vendor_id)):
    with db() as conn:
        row = conn.execute("SELECT * FROM vendors WHERE id = ?", (vendor_id,)).fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Vendor not found.")
    return {"vendor": row_to_vendor(row)}


@app.patch("/api/vendors/me")
def vendor_update(body: VendorUpdateBody, vendor_id: str = Depends(get_vendor_id)):
    with db() as conn:
        row = conn.execute("SELECT * FROM vendors WHERE id = ?", (vendor_id,)).fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Vendor not found.")
        now = utc_now()
        conn.execute(
            """
            UPDATE vendors SET
              name = ?, location = ?, description = ?, phone = ?, whatsapp = ?, updated_at = ?
            WHERE id = ?
            """,
            (
                (body.name or row["name"]).strip(),
                (body.location or row["location"]).strip(),
                (body.description if body.description is not None else row["description"]).strip(),
                (body.phone or row["phone"]).strip(),
                (body.whatsapp if body.whatsapp is not None else row["whatsapp"]).strip(),
                now,
                vendor_id,
            ),
        )
        updated = conn.execute("SELECT * FROM vendors WHERE id = ?", (vendor_id,)).fetchone()
    return {"vendor": row_to_vendor(updated)}


@app.get("/api/vendors/me/products")
def vendor_products(vendor_id: str = Depends(get_vendor_id)):
    with db() as conn:
        rows = conn.execute(
            """
            SELECT * FROM products
            WHERE vendor_id = ? AND deleted_at IS NULL
            ORDER BY updated_at DESC
            """,
            (vendor_id,),
        ).fetchall()
    return {"products": [row_to_product(row) for row in rows]}


@app.post("/api/vendors/me/products")
def vendor_create_product(body: ProductBody, vendor_id: str = Depends(get_vendor_id)):
    if not body.name.strip():
        raise HTTPException(status_code=400, detail="Product name is required.")
    if body.priceCents <= 0:
        raise HTTPException(status_code=400, detail="Valid price is required.")

    product_id = new_product_id()
    now = utc_now()
    with db() as conn:
        conn.execute(
            """
            INSERT INTO products (
              id, vendor_id, name, price_cents, description, category, tags,
              image_asset, in_stock, can_buy_online, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                product_id,
                vendor_id,
                body.name.strip(),
                body.priceCents,
                body.description.strip(),
                body.category.strip(),
                json.dumps(body.tags),
                body.imageAsset,
                1 if body.inStock else 0,
                1 if body.canBuyOnline else 0,
                now,
                now,
            ),
        )
        row = conn.execute("SELECT * FROM products WHERE id = ?", (product_id,)).fetchone()
    return {"product": row_to_product(row)}


@app.patch("/api/vendors/me/products/{product_id}")
def vendor_update_product(
    product_id: str, body: ProductUpdateBody, vendor_id: str = Depends(get_vendor_id)
):
    with db() as conn:
        row = conn.execute(
            "SELECT * FROM products WHERE id = ? AND vendor_id = ?",
            (product_id, vendor_id),
        ).fetchone()
        if not row or row["deleted_at"]:
            raise HTTPException(status_code=404, detail="Product not found.")

        now = utc_now()
        conn.execute(
            """
            UPDATE products SET
              name = ?, description = ?, category = ?, price_cents = ?, tags = ?,
              in_stock = ?, can_buy_online = ?, updated_at = ?
            WHERE id = ?
            """,
            (
                (body.name or row["name"]).strip(),
                (body.description if body.description is not None else row["description"]).strip(),
                (body.category or row["category"]).strip(),
                body.priceCents if body.priceCents is not None else row["price_cents"],
                json.dumps(body.tags if body.tags is not None else json.loads(row["tags"] or "[]")),
                1 if (body.inStock if body.inStock is not None else row["in_stock"] == 1) else 0,
                1 if (body.canBuyOnline if body.canBuyOnline is not None else row["can_buy_online"] == 1) else 0,
                now,
                product_id,
            ),
        )
        updated = conn.execute("SELECT * FROM products WHERE id = ?", (product_id,)).fetchone()
    return {"product": row_to_product(updated)}


@app.delete("/api/vendors/me/products/{product_id}")
def vendor_delete_product(product_id: str, vendor_id: str = Depends(get_vendor_id)):
    with db() as conn:
        row = conn.execute(
            "SELECT * FROM products WHERE id = ? AND vendor_id = ?",
            (product_id, vendor_id),
        ).fetchone()
        if not row or row["deleted_at"]:
            raise HTTPException(status_code=404, detail="Product not found.")
        now = utc_now()
        conn.execute(
            "UPDATE products SET deleted_at = ?, updated_at = ? WHERE id = ?",
            (now, now, product_id),
        )
    return {"ok": True, "deletedAt": now}


@app.get("/api/catalog/vendors")
def list_vendors():
    with db() as conn:
        rows = conn.execute("SELECT * FROM vendors ORDER BY name ASC").fetchall()
    return {"vendors": [row_to_vendor(row) for row in rows]}


@app.get("/api/catalog/products")
def list_products(vendorId: Optional[str] = None):
    with db() as conn:
        if vendorId:
            rows = conn.execute(
                """
                SELECT * FROM products
                WHERE vendor_id = ? AND deleted_at IS NULL
                ORDER BY updated_at DESC
                """,
                (vendorId,),
            ).fetchall()
        else:
            rows = conn.execute(
                "SELECT * FROM products WHERE deleted_at IS NULL ORDER BY updated_at DESC"
            ).fetchall()
    return {"products": [row_to_product(row) for row in rows]}


@app.get("/api/sync/catalog")
def sync_catalog(since: str = "1970-01-01T00:00:00.000Z"):
    with db() as conn:
        vendors = conn.execute(
            "SELECT * FROM vendors WHERE updated_at > ? ORDER BY updated_at ASC",
            (since,),
        ).fetchall()
        products = conn.execute(
            """
            SELECT * FROM products
            WHERE updated_at > ? AND deleted_at IS NULL
            ORDER BY updated_at ASC
            """,
            (since,),
        ).fetchall()
        deleted = conn.execute(
            "SELECT id FROM products WHERE deleted_at > ?",
            (since,),
        ).fetchall()
    return {
        "vendors": [row_to_vendor(row) for row in vendors],
        "products": [row_to_product(row) for row in products],
        "deletedProductIds": [row["id"] for row in deleted],
        "serverTime": utc_now(),
    }


@app.get("/api/sync/full-catalog")
def full_catalog():
    with db() as conn:
        vendors = conn.execute("SELECT * FROM vendors ORDER BY name ASC").fetchall()
        products = conn.execute(
            "SELECT * FROM products WHERE deleted_at IS NULL ORDER BY name ASC"
        ).fetchall()
    return {
        "vendors": [row_to_vendor(row) for row in vendors],
        "products": [row_to_product(row) for row in products],
        "serverTime": utc_now(),
    }


@app.post("/api/devices/register")
def device_register(body: DeviceRegisterBody):
    import uuid

    device_id = body.deviceId or str(uuid.uuid4())
    ensure_device(device_id)
    with db() as conn:
        conn.execute(
            "UPDATE devices SET updated_at = ? WHERE id = ?",
            (utc_now(), device_id),
        )
    return {"deviceId": device_id}


@app.get("/api/devices/{device_id}/state")
def device_state(device_id: str):
    ensure_device(device_id)
    with db() as conn:
        profile = conn.execute(
            "SELECT * FROM device_profiles WHERE device_id = ?", (device_id,)
        ).fetchone()
        subscription = conn.execute(
            "SELECT * FROM subscriptions WHERE device_id = ?", (device_id,)
        ).fetchone()
        orders = conn.execute(
            "SELECT * FROM orders WHERE device_id = ? ORDER BY created_at DESC LIMIT 50",
            (device_id,),
        ).fetchall()

    return {
        "profile": {
            "name": profile["name"],
            "email": profile["email"],
            "allergies": profile["allergies"],
            "emergencyContact": profile["emergency_contact"],
            "updatedAt": profile["updated_at"],
        },
        "subscription": {
            "isPremium": subscription["is_premium"] == 1,
            "checksUsed": subscription["checks_used"],
            "updatedAt": subscription["updated_at"],
        },
        "orders": [
            {
                "id": row["id"],
                "vendorId": row["vendor_id"],
                "reference": row["reference"],
                "totalCents": row["total_cents"],
                "status": row["status"],
                "items": json.loads(row["items"]),
                "createdAt": row["created_at"],
                "updatedAt": row["updated_at"],
            }
            for row in orders
        ],
        "serverTime": utc_now(),
    }


@app.put("/api/devices/{device_id}/profile")
def device_profile(device_id: str, body: ProfileBody):
    ensure_device(device_id)
    now = utc_now()
    with db() as conn:
        conn.execute(
            """
            UPDATE device_profiles SET
              name = ?, email = ?, allergies = ?, emergency_contact = ?, updated_at = ?
            WHERE device_id = ?
            """,
            (
                body.name.strip(),
                body.email.strip(),
                body.allergies.strip(),
                body.emergencyContact.strip(),
                now,
                device_id,
            ),
        )
        conn.execute(
            "UPDATE devices SET updated_at = ? WHERE id = ?",
            (now, device_id),
        )
    return {
        "profile": {
            "name": body.name,
            "email": body.email,
            "allergies": body.allergies,
            "emergencyContact": body.emergencyContact,
            "updatedAt": now,
        }
    }


@app.post("/api/devices/{device_id}/check")
def device_check(device_id: str):
    ensure_device(device_id)
    with db() as conn:
        sub = conn.execute(
            "SELECT * FROM subscriptions WHERE device_id = ?", (device_id,)
        ).fetchone()
        is_premium = sub["is_premium"] == 1
        if not is_premium and sub["checks_used"] >= 3:
            return {
                "allowed": False,
                "isPremium": False,
                "checksUsed": sub["checks_used"],
                "checksRemaining": 0,
            }
        checks_used = sub["checks_used"]
        if not is_premium:
            checks_used += 1
            now = utc_now()
            conn.execute(
                "UPDATE subscriptions SET checks_used = ?, updated_at = ? WHERE device_id = ?",
                (checks_used, now, device_id),
            )
    return {
        "allowed": True,
        "isPremium": is_premium,
        "checksUsed": checks_used,
        "checksRemaining": 999 if is_premium else max(0, 3 - checks_used),
    }


@app.post("/api/devices/{device_id}/subscriptions/activate")
def device_activate(device_id: str, body: ActivateBody):
    ensure_device(device_id)
    if not is_valid_token(body.token):
        raise HTTPException(status_code=400, detail="Invalid activation token.")
    now = utc_now()
    with db() as conn:
        conn.execute(
            "UPDATE subscriptions SET is_premium = 1, updated_at = ? WHERE device_id = ?",
            (now, device_id),
        )
    return {"isPremium": True, "updatedAt": now}


@app.post("/api/devices/{device_id}/orders")
def device_order(device_id: str, body: OrderBody):
    ensure_device(device_id)
    if not body.vendorId or not body.items:
        raise HTTPException(status_code=400, detail="vendorId and items are required.")

    order_id = body.id or new_order_id()
    now = utc_now()
    with db() as conn:
        existing = conn.execute("SELECT id FROM orders WHERE id = ?", (order_id,)).fetchone()
        if existing:
            return {"order": {"id": order_id}, "duplicate": True}

        conn.execute(
            """
            INSERT INTO orders (
              id, device_id, vendor_id, reference, total_cents, status, items, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                order_id,
                device_id,
                body.vendorId,
                body.reference or order_id,
                body.totalCents,
                body.status,
                json.dumps(body.items),
                now,
                now,
            ),
        )
    return {
        "order": {
            "id": order_id,
            "vendorId": body.vendorId,
            "reference": body.reference or order_id,
            "totalCents": body.totalCents,
            "status": body.status,
            "items": body.items,
            "createdAt": now,
            "updatedAt": now,
        }
    }


@app.patch("/api/vendors/me/orders/{order_id}")
def vendor_update_order(
    order_id: str, body: OrderStatusBody, vendor_id: str = Depends(get_vendor_id)
):
    valid = {"pending", "confirmed", "delivered", "cancelled"}
    if body.status not in valid:
        raise HTTPException(status_code=400, detail=f"Status must be one of {valid}.")
    with db() as conn:
        row = conn.execute(
            "SELECT * FROM orders WHERE id = ? AND vendor_id = ?",
            (order_id, vendor_id),
        ).fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Order not found.")
        now = utc_now()
        conn.execute(
            "UPDATE orders SET status = ?, updated_at = ? WHERE id = ?",
            (body.status, now, order_id),
        )
    return {"order": {"id": order_id, "status": body.status, "updatedAt": now}}


@app.get("/api/vendors/me/orders")
def vendor_orders(vendor_id: str = Depends(get_vendor_id)):
    with db() as conn:
        rows = conn.execute(
            "SELECT * FROM orders WHERE vendor_id = ? ORDER BY created_at DESC",
            (vendor_id,),
        ).fetchall()
    return {
        "orders": [
            {
                "id": row["id"],
                "deviceId": row["device_id"],
                "vendorId": row["vendor_id"],
                "reference": row["reference"],
                "totalCents": row["total_cents"],
                "status": row["status"],
                "items": json.loads(row["items"]),
                "createdAt": row["created_at"],
                "updatedAt": row["updated_at"],
            }
            for row in rows
        ]
    }


@app.post("/api/products/{product_id}/image")
def upload_product_image(
    product_id: str, file: UploadFile = File(...), vendor_id: str = Depends(get_vendor_id)
):
    with db() as conn:
        row = conn.execute(
            "SELECT * FROM products WHERE id = ? AND vendor_id = ?",
            (product_id, vendor_id),
        ).fetchone()
        if not row or row["deleted_at"]:
            raise HTTPException(status_code=404, detail="Product not found.")

    allowed = {"image/jpeg", "image/png", "image/webp", "image/gif"}
    if file.content_type not in allowed:
        raise HTTPException(status_code=400, detail=f"Unsupported type: {file.content_type}")

    ext = file.content_type.split("/")[-1]
    filename = f"{product_id}_{uuid.uuid4().hex[:8]}.{ext}"
    dest = UPLOAD_DIR / filename
    content = file.file.read()
    if len(content) > 5 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="File too large (max 5 MB).")
    dest.write_bytes(content)

    asset_url = f"/uploads/{filename}"
    now = utc_now()
    with db() as conn:
        conn.execute(
            "UPDATE products SET image_asset = ?, updated_at = ? WHERE id = ?",
            (asset_url, now, product_id),
        )
    return {"imageAsset": asset_url}


@app.get("/uploads/{filename}")
def serve_upload(filename: str):
    path = UPLOAD_DIR / filename
    if not path.is_file():
        raise HTTPException(status_code=404, detail="File not found.")
    return FileResponse(path)


@app.post("/api/reviews")
def create_review(body: ReviewBody):
    with db() as conn:
        vendor = conn.execute("SELECT id FROM vendors WHERE id = ?", (body.vendorId,)).fetchone()
        if not vendor:
            raise HTTPException(status_code=404, detail="Vendor not found.")

        existing = conn.execute(
            "SELECT id FROM reviews WHERE vendor_id = ? AND device_id = ?",
            (body.vendorId, body.deviceId),
        ).fetchone()
        if existing:
            raise HTTPException(status_code=409, detail="You already reviewed this vendor.")

        review_id = new_review_id()
        now = utc_now()
        conn.execute(
            "INSERT INTO reviews (id, vendor_id, device_id, rating, comment, created_at) VALUES (?, ?, ?, ?, ?, ?)",
            (review_id, body.vendorId, body.deviceId, body.rating, body.comment.strip(), now),
        )

        agg = conn.execute(
            "SELECT AVG(rating) as avg_rating, COUNT(*) as cnt FROM reviews WHERE vendor_id = ?",
            (body.vendorId,),
        ).fetchone()
        conn.execute(
            "UPDATE vendors SET rating = ?, review_count = ? WHERE id = ?",
            (round(agg["avg_rating"], 1), agg["cnt"], body.vendorId),
        )

    return {
        "review": {
            "id": review_id,
            "vendorId": body.vendorId,
            "rating": body.rating,
            "comment": body.comment,
            "createdAt": now,
        }
    }


@app.get("/api/vendors/{vendor_id}/reviews")
def list_vendor_reviews(vendor_id: str):
    with db() as conn:
        rows = conn.execute(
            "SELECT * FROM reviews WHERE vendor_id = ? ORDER BY created_at DESC",
            (vendor_id,),
        ).fetchall()
    return {
        "reviews": [
            {
                "id": row["id"],
                "vendorId": row["vendor_id"],
                "rating": row["rating"],
                "comment": row["comment"],
                "createdAt": row["created_at"],
            }
            for row in rows
        ]
    }
