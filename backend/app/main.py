import json
import logging
import os
import re
import time
import uuid
from datetime import datetime, timedelta, timezone
from contextlib import asynccontextmanager
from pathlib import Path
from typing import Optional

import bcrypt
import jwt
from dotenv import load_dotenv
from fastapi import Depends, FastAPI, File, Header, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse, RedirectResponse
from pydantic import BaseModel, Field
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request

from .database import (
    DATABASE_URL,
    db,
    init_schema,
    row_to_product,
    row_to_vendor,
    token_digest,
    utc_now,
)
from .id_factory import new_order_id, new_product_id, new_review_id, new_vendor_id

logger = logging.getLogger("usizo")
UPLOAD_DIR = Path(__file__).parent.parent / "data" / "uploads"
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
PAYMENT_PROOF_DIR = Path(__file__).parent.parent / "data" / "payment_proofs"
PAYMENT_PROOF_DIR.mkdir(parents=True, exist_ok=True)

load_dotenv()

JWT_SECRET = os.getenv("JWT_SECRET")
JWT_ALG = "HS256"
JWT_TTL_HOURS = int(os.getenv("JWT_TTL_HOURS", "12"))
ENVIRONMENT = os.getenv("ENVIRONMENT", "development").lower()
ALLOWED_ORIGINS = [origin.strip() for origin in os.getenv("CORS_ALLOWED_ORIGINS", "").split(",") if origin.strip()]
RATE_LIMIT_WINDOW_SECONDS = 60
RATE_LIMIT_DEFAULT = int(os.getenv("RATE_LIMIT_DEFAULT_PER_MINUTE", "120"))
RATE_LIMIT_AUTH = int(os.getenv("RATE_LIMIT_AUTH_PER_MINUTE", "10"))
RATE_LIMIT_UPLOAD = int(os.getenv("RATE_LIMIT_UPLOADS_PER_MINUTE", "12"))
RATE_LIMIT_SUBMISSIONS = int(os.getenv("RATE_LIMIT_SUBMISSIONS_PER_MINUTE", "6"))


class RateLimitMiddleware(BaseHTTPMiddleware):
    """Apply bounded in-memory limits per client process and IP address."""

    def __init__(self, app):
        super().__init__(app)
        self._requests: dict[tuple[str, str], tuple[int, float]] = {}

    def _limit_for(self, path: str) -> int:
        if path in ("/api/auth/register", "/api/auth/login"):
            return RATE_LIMIT_AUTH
        if path.endswith("/payment-proof"):
            return RATE_LIMIT_UPLOAD
        if path == "/api/remedy-submissions":
            return RATE_LIMIT_SUBMISSIONS
        return RATE_LIMIT_DEFAULT

    async def dispatch(self, request: Request, call_next):
        now = time.monotonic()
        path = request.url.path
        limit = self._limit_for(path)
        forwarded_for = request.headers.get("x-forwarded-for")
        client_ip = (
            forwarded_for.split(",")[0].strip()
            if forwarded_for
            else (request.client.host if request.client else "unknown")
        )
        key = (client_ip, path)
        count, window_start = self._requests.get(key, (0, now))
        if now - window_start >= RATE_LIMIT_WINDOW_SECONDS:
            count, window_start = 0, now
        if count >= limit:
            retry_after = max(1, int(RATE_LIMIT_WINDOW_SECONDS - (now - window_start)))
            return JSONResponse(
                status_code=429,
                content={"detail": "Too many requests. Please try again later."},
                headers={"Retry-After": str(retry_after)},
            )
        self._requests[key] = (count + 1, window_start)
        if len(self._requests) > 10_000:
            self._requests = {
                item_key: item
                for item_key, item in self._requests.items()
                if now - item[1] < RATE_LIMIT_WINDOW_SECONDS
            }
        return await call_next(request)


@asynccontextmanager
async def lifespan(app: FastAPI):
    if ENVIRONMENT == "production" and (not JWT_SECRET or len(JWT_SECRET) < 32):
        raise RuntimeError("JWT_SECRET must be set to at least 32 characters in production.")
    if ENVIRONMENT == "production" and not ALLOWED_ORIGINS:
        raise RuntimeError("CORS_ALLOWED_ORIGINS must be configured in production.")
    if ENVIRONMENT == "production" and not DATABASE_URL.startswith(
        ("postgres://", "postgresql://")
    ):
        raise RuntimeError("DATABASE_URL must be a PostgreSQL URL in production.")
    init_schema()
    if ENVIRONMENT == "production":
        _ensure_production_supplier()
    yield


def _ensure_production_supplier() -> None:
    """Keep production limited to the current supplier until products are added."""
    now = utc_now()
    with db() as conn:
        conn.execute("DELETE FROM products")
        conn.execute(
            "DELETE FROM vendors WHERE phone <> ? AND NOT EXISTS "
            "(SELECT 1 FROM orders WHERE orders.vendor_id = vendors.id)",
            ("+263 780747989",),
        )
        existing = conn.execute(
            "SELECT id FROM vendors WHERE phone = ?",
            ("+263 780747989",),
        ).fetchone()
        if existing:
            conn.execute(
                "UPDATE vendors SET name = ?, location = ?, description = ?, "
                "whatsapp = ?, ecocash_number = ?, updated_at = ? WHERE phone = ?",
                (
                    "Treasure Motsu",
                    "Bulawayo",
                    "Supplier for UsizoAI marketplace products.",
                    "+263 780747989",
                    "+263 780747989",
                    now,
                    "+263 780747989",
                ),
            )
        else:
            conn.execute(
                """
                INSERT INTO vendors (
                  id, name, location, description, phone, whatsapp,
                  ecocash_number, rating, review_count, pin_hash, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, 0, 0, ?, ?, ?)
                """,
                (
                    "vendor-treasure-motsu",
                    "Treasure Motsu",
                    "Bulawayo",
                    "Supplier for UsizoAI marketplace products.",
                    "+263 780747989",
                    "+263 780747989",
                    "+263 780747989",
                    bcrypt.hashpw(b"change-this-pin", bcrypt.gensalt()).decode("utf-8"),
                    now,
                    now,
                ),
            )


app = FastAPI(title="UsizoAI API", version="1.0.0", lifespan=lifespan, docs_url=None if ENVIRONMENT == "production" else "/docs")
app.add_middleware(RateLimitMiddleware)
app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS or (["*"] if ENVIRONMENT != "production" else []),
    allow_credentials=bool(ALLOWED_ORIGINS),
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
    if not JWT_SECRET:
        raise RuntimeError("JWT_SECRET must be configured before vendor authentication is used.")
    now = datetime.now(timezone.utc)
    return jwt.encode(
        {"vendorId": vendor_id, "role": "vendor", "iat": now, "exp": now + timedelta(hours=JWT_TTL_HOURS)},
        JWT_SECRET,
        algorithm=JWT_ALG,
    )


def sign_account_token(user_id: str) -> str:
    if not JWT_SECRET:
        raise RuntimeError("JWT_SECRET must be configured before account authentication is used.")
    now = datetime.now(timezone.utc)
    return jwt.encode(
        {"userId": user_id, "role": "customer", "iat": now, "exp": now + timedelta(hours=JWT_TTL_HOURS)},
        JWT_SECRET,
        algorithm=JWT_ALG,
    )


def get_account_id(authorization: Optional[str] = Header(default=None)) -> str:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Account authentication required.")
    try:
        payload = jwt.decode(authorization[7:], JWT_SECRET, algorithms=[JWT_ALG])
    except jwt.PyJWTError as exc:
        raise HTTPException(status_code=401, detail="Invalid or expired account token.") from exc
    if payload.get("role") != "customer" or not payload.get("userId"):
        raise HTTPException(status_code=401, detail="Invalid customer token.")
    return payload["userId"]


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
    ecocashNumber: str = ""
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
    ecocashNumber: Optional[str] = None
    whatsapp: Optional[str] = None


class ProductBody(BaseModel):
    name: str
    description: str = ""
    category: str = "Herbal remedy"
    priceCents: int = Field(ge=1, le=10_000_000)
    tags: list[str] = Field(default_factory=list)
    inStock: bool = True
    canBuyOnline: bool = False
    imageAsset: Optional[str] = None


class ProductUpdateBody(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    category: Optional[str] = None
    priceCents: Optional[int] = Field(default=None, ge=1, le=10_000_000)
    tags: Optional[list[str]] = None
    inStock: Optional[bool] = None
    canBuyOnline: Optional[bool] = None


class DeviceRegisterBody(BaseModel):
    deviceId: Optional[str] = None
    accountToken: Optional[str] = None


class AccountRegisterBody(BaseModel):
    email: Optional[str] = None
    phone: Optional[str] = None
    password: str = Field(min_length=8, max_length=128)
    name: str = Field(min_length=1, max_length=120)
    allergies: str = Field(default="", max_length=1000)
    emergencyContact: str = Field(default="", max_length=100)


class AccountLoginBody(BaseModel):
    identifier: str = Field(min_length=3, max_length=254)
    password: str = Field(min_length=1, max_length=128)


class ProfileBody(BaseModel):
    name: str = ""
    email: str = ""
    allergies: str = ""
    medicalConditions: str = ""
    currentMedications: str = ""
    emergencyContact: str = ""


class ActivateBody(BaseModel):
    token: str


class OrderBody(BaseModel):
    id: Optional[str] = None
    vendorId: str
    reference: Optional[str] = None
    # Pricing and status are derived server-side. These remain optional only
    # for compatibility with older mobile releases and are never trusted.
    totalCents: Optional[int] = None
    items: list[dict] = Field(min_length=1, max_length=50)


class ReviewBody(BaseModel):
    vendorId: str
    rating: int = Field(ge=1, le=5)
    comment: str = ""
    deviceId: str


class RemedySubmissionBody(BaseModel):
    deviceId: str = Field(min_length=1, max_length=100)
    name: str = Field(min_length=2, max_length=120)
    scientificName: str = Field(default="", max_length=200)
    localNames: dict[str, str] = Field(default_factory=dict)
    category: str = Field(min_length=2, max_length=80)
    description: str = Field(min_length=10, max_length=1000)
    usage: str = Field(min_length=10, max_length=1000)
    preparation: str = Field(min_length=10, max_length=1000)
    dosage: str = Field(min_length=5, max_length=500)
    warning: str = Field(min_length=10, max_length=1000)
    evidenceSource: str = Field(min_length=5, max_length=500)
    studyUrl: str = Field(default="", max_length=500)
    tags: list[str] = Field(default_factory=list, max_length=20)


class RemedyModerationBody(BaseModel):
    action: str
    moderationNote: str = Field(default="", max_length=1000)


class OrderStatusBody(BaseModel):
    status: str
    rejectionReason: str = Field(default="", max_length=500)


class OrderConfirmBody(BaseModel):
    """Vendor confirms or declines an order with delivery and payment details."""
    action: str  # 'confirm' or 'decline'
    finalPriceCents: Optional[int] = None
    deliveryMethod: str = Field(default="", max_length=50)  # 'delivery' or 'collection'
    deliveryArea: str = Field(default="", max_length=200)
    collectionPoint: str = Field(default="", max_length=200)
    turnaroundTime: str = Field(default="", max_length=100)
    paymentInstructions: str = Field(default="", max_length=1000)
    deliveryInstructions: str = Field(default="", max_length=1000)
    vendorNotes: str = Field(default="", max_length=1000)
    declineReason: str = Field(default="", max_length=500)


ADMIN_HTML = Path(__file__).parent / "static" / "admin.html"
LANDING_HTML = Path(__file__).parent / "static" / "index.html"
APK_DOWNLOAD_URL = os.getenv(
    "APK_DOWNLOAD_URL",
    "https://github.com/phallenges/usizo_ai_web/releases/download/v1.0.0/app-release.apk",
).strip()


@app.get("/")
def landing_page():
    if not LANDING_HTML.is_file():
        raise HTTPException(status_code=404, detail="Landing page not found.")
    return FileResponse(str(LANDING_HTML), media_type="text/html")


@app.get("/download")
def download_apk():
    if not APK_DOWNLOAD_URL.startswith(("https://", "http://")):
        raise HTTPException(status_code=503, detail="APK download is not configured.")
    return RedirectResponse(APK_DOWNLOAD_URL, status_code=302)


@app.get("/admin")
def admin_dashboard():
    if not ADMIN_HTML.is_file():
        raise HTTPException(status_code=404, detail="Admin dashboard not found.")
    return FileResponse(str(ADMIN_HTML), media_type="text/html")


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
    if not re.fullmatch(r"\d{4,64}", body.pin):
        raise HTTPException(status_code=400, detail="PIN must contain 4 to 64 digits.")

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
              id, name, location, description, phone, ecocash_number, whatsapp,
              rating, review_count, pin_hash, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, 0, 0, ?, ?, ?)
            """,
            (
                vendor_id,
                body.businessName.strip(),
                body.location.strip(),
                body.description.strip(),
                normalized,
                normalize_phone(body.ecocashNumber),
                normalize_phone(body.whatsapp) or normalized,
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
            (normalized, normalized),
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
              name = ?, location = ?, description = ?, phone = ?, ecocash_number = ?, whatsapp = ?, updated_at = ?
            WHERE id = ?
            """,
            (
                (body.name or row["name"]).strip(),
                (body.location or row["location"]).strip(),
                (body.description if body.description is not None else row["description"]).strip(),
                normalize_phone(body.phone) if body.phone is not None else row["phone"],
                normalize_phone(body.ecocashNumber)
                if body.ecocashNumber is not None
                else row["ecocash_number"],
                normalize_phone(body.whatsapp) if body.whatsapp is not None else row["whatsapp"],
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


def row_to_remedy_submission(row) -> dict:
    return {
        "id": row["id"],
        "name": row["name"],
        "scientificName": row["scientific_name"],
        "localNames": json.loads(row["local_names"] or "{}"),
        "category": row["category"],
        "description": row["description"],
        "usage": row["usage"],
        "preparation": row["preparation"],
        "dosage": row["dosage"],
        "warning": row["warning"],
        "evidenceSource": row["evidence_source"],
        "studyUrl": row["study_url"],
        "priceCents": 0,
        "tags": json.loads(row["tags"] or "[]"),
        "status": row["status"],
        "createdAt": row["created_at"],
    }


@app.get("/api/catalog/remedies")
def list_approved_remedies():
    with db() as conn:
        rows = conn.execute(
            """
            SELECT * FROM remedy_submissions
            WHERE status = 'approved'
            ORDER BY created_at DESC
            """
        ).fetchall()
    return {"remedies": [row_to_remedy_submission(row) for row in rows]}


@app.post("/api/remedy-submissions")
def submit_remedy(body: RemedySubmissionBody):
    ensure_device(body.deviceId)
    if len(body.localNames) > 10:
        raise HTTPException(status_code=400, detail="Too many local names.")
    if any(len(key) > 10 or len(value) > 120 for key, value in body.localNames.items()):
        raise HTTPException(status_code=400, detail="Local names are too long.")
    if any(len(tag) > 50 or not tag.strip() for tag in body.tags):
        raise HTTPException(status_code=400, detail="Tags must be non-empty and short.")
    if body.studyUrl and not body.studyUrl.startswith(("https://", "http://")):
        raise HTTPException(status_code=400, detail="Study URL must use http or https.")

    submission_id = f"remedy-submission-{uuid.uuid4()}"
    now = utc_now()
    with db() as conn:
        recent = conn.execute(
            """
            SELECT COUNT(*) FROM remedy_submissions
            WHERE device_id = ? AND created_at > ?
            """,
            (body.deviceId, (datetime.now(timezone.utc) - timedelta(days=1)).isoformat()),
        ).fetchone()[0]
        if recent >= 5:
            raise HTTPException(
                status_code=429,
                detail="Submission limit reached. Please try again tomorrow.",
            )
        conn.execute(
            """
            INSERT INTO remedy_submissions (
              id, device_id, name, scientific_name, local_names, category,
              description, usage, preparation, dosage, warning, evidence_source,
              study_url, tags, status, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', ?)
            """,
            (
                submission_id,
                body.deviceId,
                body.name.strip(),
                body.scientificName.strip(),
                json.dumps(body.localNames),
                body.category.strip(),
                body.description.strip(),
                body.usage.strip(),
                body.preparation.strip(),
                body.dosage.strip(),
                body.warning.strip(),
                body.evidenceSource.strip(),
                body.studyUrl.strip(),
                json.dumps([tag.strip() for tag in body.tags]),
                now,
            ),
        )
    audit(
        "remedy_submitted",
        actor_type="device",
        actor_id=body.deviceId,
        target_type="remedy_submission",
        target_id=submission_id,
    )
    return {"submissionId": submission_id, "status": "pending"}


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


def account_payload(row) -> dict:
    return {
        "id": row["id"],
        "email": row["email"],
        "phone": row["phone"],
        "name": row["name"],
        "allergies": row["allergies"],
        "emergencyContact": row["emergency_contact"],
    }


@app.post("/api/auth/register")
def account_register(body: AccountRegisterBody):
    email = body.email.strip().lower() if body.email else ""
    phone = normalize_phone(body.phone) if body.phone else ""
    if not email and not phone:
        raise HTTPException(status_code=400, detail="Email or phone number is required.")
    if email and not re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", email):
        raise HTTPException(status_code=400, detail="Enter a valid email address.")
    if phone and not re.fullmatch(r"\+?[0-9]{7,20}", phone):
        raise HTTPException(status_code=400, detail="Enter a valid phone number.")
    user_id = f"user-{uuid.uuid4()}"
    now = utc_now()
    password_hash = bcrypt.hashpw(body.password.encode(), bcrypt.gensalt()).decode()
    with db() as conn:
        existing = conn.execute(
            "SELECT id FROM users WHERE (email = ? AND email <> '') OR (phone = ? AND phone <> '')",
            (email, phone),
        ).fetchone()
        if existing:
            raise HTTPException(status_code=409, detail="An account with those details already exists.")
        conn.execute(
            """
            INSERT INTO users (
              id, email, phone, password_hash, name, allergies, emergency_contact,
              created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                user_id,
                email or None,
                phone or None,
                password_hash,
                body.name.strip(),
                body.allergies.strip(),
                body.emergencyContact.strip(),
                now,
                now,
            ),
        )
        row = conn.execute(
            "SELECT * FROM users WHERE id = ?",
            (user_id,),
        ).fetchone()
    return {"account": account_payload(row), "token": sign_account_token(user_id)}


@app.post("/api/auth/login")
def account_login(body: AccountLoginBody):
    identifier = body.identifier.strip().lower()
    normalized_phone = normalize_phone(identifier)
    with db() as conn:
        row = conn.execute(
            "SELECT u.* FROM users u "
            "WHERE lower(u.email) = ? OR u.phone = ?",
            (identifier, normalized_phone),
        ).fetchone()
    if not row or not bcrypt.checkpw(body.password.encode(), row["password_hash"].encode()):
        raise HTTPException(status_code=401, detail="Invalid email/phone or password.")
    return {"account": account_payload(row), "token": sign_account_token(row["id"])}


@app.get("/api/auth/me")
def account_me(account_id: str = Depends(get_account_id)):
    with db() as conn:
        row = conn.execute(
            "SELECT u.* FROM users u "
            "WHERE u.id = ?",
            (account_id,),
        ).fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Account not found.")
    return {"account": account_payload(row)}


@app.post("/api/devices/register")
def device_register(body: DeviceRegisterBody, authorization: Optional[str] = Header(default=None)):
    import uuid

    device_id = body.deviceId or str(uuid.uuid4())
    ensure_device(device_id)
    account_id = None
    if authorization and authorization.startswith("Bearer "):
        try:
            account_id = get_account_id(authorization)
        except HTTPException:
            account_id = None
    with db() as conn:
        if account_id:
            conn.execute("UPDATE devices SET user_id = ?, updated_at = ? WHERE id = ?", (account_id, utc_now(), device_id))
        else:
            conn.execute("UPDATE devices SET updated_at = ? WHERE id = ?", (utc_now(), device_id))
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
            "medicalConditions": profile["medical_conditions"],
            "currentMedications": profile["current_medications"],
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
              name = ?, email = ?, allergies = ?, medical_conditions = ?,
              current_medications = ?, emergency_contact = ?, updated_at = ?
            WHERE device_id = ?
            """,
            (
                body.name.strip(),
                body.email.strip(),
                body.allergies.strip(),
                body.medicalConditions.strip(),
                body.currentMedications.strip(),
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
            "medicalConditions": body.medicalConditions,
            "currentMedications": body.currentMedications,
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
    now = utc_now()
    with db() as conn:
        token = conn.execute(
            "SELECT * FROM activation_tokens WHERE token_hash = ?",
            (token_digest(body.token),),
        ).fetchone()
        if not token or token["redeemed_at"]:
            raise HTTPException(status_code=400, detail="Invalid or already redeemed activation token.")
        conn.execute(
            "UPDATE activation_tokens SET redeemed_by_device_id = ?, redeemed_at = ? WHERE token_hash = ? AND redeemed_at IS NULL",
            (device_id, now, token["token_hash"]),
        )
        conn.execute(
            "UPDATE subscriptions SET is_premium = 1, updated_at = ? WHERE device_id = ?",
            (now, device_id),
        )
    return {"isPremium": True, "updatedAt": now}


def order_payload(row) -> dict:
    """Return the customer-safe order representation used by both portals."""
    return {
        "id": row["id"],
        "deviceId": row["device_id"],
        "vendorId": row["vendor_id"],
        "reference": row["reference"],
        "totalCents": row["total_cents"],
        "status": row["status"],
        "items": json.loads(row["items"]),
        "hasPaymentProof": bool(row["payment_proof_path"]),
        "paymentRejectionReason": row["payment_rejection_reason"] or "",
        "finalPriceCents": row["final_price_cents"],
        "deliveryMethod": row["delivery_method"] or "",
        "deliveryArea": row["delivery_area"] or "",
        "collectionPoint": row["collection_point"] or "",
        "turnaroundTime": row["turnaround_time"] or "",
        "paymentInstructions": row["payment_instructions"] or "",
        "deliveryInstructions": row["delivery_instructions"] or "",
        "vendorNotes": row["vendor_notes"] or "",
        "createdAt": row["created_at"],
        "updatedAt": row["updated_at"],
    }


def save_payment_proof(order_id: str, file: UploadFile) -> str:
    """Validate and store one bounded payment-confirmation image."""
    allowed = {
        "image/jpeg": (b"\xff\xd8\xff", "jpg"),
        "image/png": (b"\x89PNG\r\n\x1a\n", "png"),
        "image/webp": (b"RIFF", "webp"),
    }
    if file.content_type not in allowed:
        raise HTTPException(status_code=400, detail="Use a JPEG, PNG, or WebP confirmation image.")
    content = file.file.read(5 * 1024 * 1024 + 1)
    signature, extension = allowed[file.content_type]
    if len(content) > 5 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="Payment proof must be 5 MB or smaller.")
    if not content.startswith(signature):
        raise HTTPException(status_code=400, detail="File content does not match its declared image type.")
    filename = f"{order_id}_{uuid.uuid4().hex[:12]}.{extension}"
    (PAYMENT_PROOF_DIR / filename).write_bytes(content)
    return filename


@app.post("/api/orders/{order_id}/payment-proof")
def upload_payment_proof(
    order_id: str,
    file: UploadFile = File(...),
    device_id: Optional[str] = Header(default=None),
):
    """Customer uploads a payment confirmation image for an order."""
    with db() as conn:
        row = conn.execute("SELECT * FROM orders WHERE id = ?", (order_id,)).fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Order not found.")
        if device_id and row["device_id"] != device_id:
            raise HTTPException(status_code=403, detail="Not your order.")
        if row["status"] not in ("pending", "payment_rejected"):
            raise HTTPException(status_code=409, detail="Order is not awaiting payment proof.")

    filename = save_payment_proof(order_id, file)
    now = utc_now()
    with db() as conn:
        conn.execute(
            "UPDATE orders SET payment_proof_path = ?, status = ?, payment_rejection_reason = '', updated_at = ? WHERE id = ?",
            (filename, "payment_proof_submitted", now, order_id),
        )
        updated = conn.execute("SELECT * FROM orders WHERE id = ?", (order_id,)).fetchone()
    return {"order": order_payload(updated)}


@app.post("/api/vendors/me/orders/{order_id}/payment-proof")
def vendor_review_payment(
    order_id: str,
    body: OrderStatusBody,
    vendor_id: str = Depends(get_vendor_id),
):
    """Vendor approves or rejects a customer's payment proof."""
    if body.status not in ("confirmed", "payment_rejected"):
        raise HTTPException(status_code=400, detail="Status must be 'confirmed' or 'payment_rejected'.")
    with db() as conn:
        row = conn.execute(
            "SELECT * FROM orders WHERE id = ? AND vendor_id = ?",
            (order_id, vendor_id),
        ).fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Order not found.")
        if row["status"] != "payment_proof_submitted":
            raise HTTPException(status_code=409, detail="Order is not awaiting payment review.")
        now = utc_now()
        conn.execute(
            "UPDATE orders SET status = ?, payment_rejection_reason = ?, updated_at = ? WHERE id = ?",
            (body.status, body.rejectionReason, now, order_id),
        )
        updated = conn.execute("SELECT * FROM orders WHERE id = ?", (order_id,)).fetchone()
    return {"order": order_payload(updated)}


@app.post("/api/devices/{device_id}/orders")
def device_order(device_id: str, body: OrderBody):
    ensure_device(device_id)
    if not body.vendorId or not body.items:
        raise HTTPException(status_code=400, detail="vendorId and items are required.")

    order_id = body.id or new_order_id()
    now = utc_now()
    with db() as conn:
        vendor = conn.execute("SELECT id FROM vendors WHERE id = ?", (body.vendorId,)).fetchone()
        if not vendor:
            raise HTTPException(status_code=404, detail="Vendor not found.")
        existing = conn.execute("SELECT id FROM orders WHERE id = ?", (order_id,)).fetchone()
        if existing:
            return {"order": {"id": order_id}, "duplicate": True}

        quantities: dict[str, int] = {}
        for item in body.items:
            product_id = str(item.get("productId", "")).strip()
            quantity = item.get("quantity", 1)
            if not product_id or not isinstance(quantity, int) or isinstance(quantity, bool) or not 1 <= quantity <= 20:
                raise HTTPException(status_code=400, detail="Each item needs a productId and quantity from 1 to 20.")
            quantities[product_id] = quantities.get(product_id, 0) + quantity

        product_ids = list(quantities)
        placeholders = ",".join("?" for _ in product_ids)
        products = conn.execute(
            f"SELECT * FROM products WHERE id IN ({placeholders}) AND vendor_id = ? AND deleted_at IS NULL",
            (*product_ids, body.vendorId),
        ).fetchall()
        if len(products) != len(product_ids):
            raise HTTPException(status_code=400, detail="One or more products are unavailable from this vendor.")
        canonical_items = []
        total_cents = 0
        for product in products:
            if product["in_stock"] != 1:
                raise HTTPException(status_code=409, detail=f"{product['name']} is out of stock.")
            quantity = quantities[product["id"]]
            price_cents = product["price_cents"]
            total_cents += price_cents * quantity
            canonical_items.append({
                "productId": product["id"], "name": product["name"],
                "priceCents": price_cents, "quantity": quantity,
            })

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
                total_cents,
                "pending",
                json.dumps(canonical_items),
                now,
                now,
            ),
        )
    return {
        "order": {
            "id": order_id,
            "vendorId": body.vendorId,
            "reference": body.reference or order_id,
            "totalCents": total_cents,
            "status": "pending",
            "items": canonical_items,
            "createdAt": now,
            "updatedAt": now,
        }
    }


@app.patch("/api/vendors/me/orders/{order_id}")
def vendor_update_order(
    order_id: str, body: OrderStatusBody, vendor_id: str = Depends(get_vendor_id)
):
    valid = {"confirmed", "delivered", "cancelled"}
    if body.status not in valid:
        raise HTTPException(status_code=400, detail=f"Status must be one of {valid}.")
    with db() as conn:
        row = conn.execute(
            "SELECT * FROM orders WHERE id = ? AND vendor_id = ?",
            (order_id, vendor_id),
        ).fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Order not found.")
        transitions = {
            "pending": {"confirmed", "cancelled"},
            "payment_proof_submitted": {"confirmed", "cancelled"},
            "payment_rejected": {"cancelled"},
            "confirmed": {"delivered", "cancelled"},
            "delivered": set(),
            "cancelled": set(),
        }
        if body.status not in transitions[row["status"]]:
            raise HTTPException(status_code=409, detail=f"Cannot change {row['status']} order to {body.status}.")
        now = utc_now()
        conn.execute(
            "UPDATE orders SET status = ?, updated_at = ? WHERE id = ?",
            (body.status, now, order_id),
        )
    return {"order": {"id": order_id, "status": body.status, "updatedAt": now}}


@app.post("/api/vendors/me/orders/{order_id}/confirm")
def vendor_confirm_order(
    order_id: str, body: OrderConfirmBody, vendor_id: str = Depends(get_vendor_id)
):
    """Vendor confirms or declines an order with delivery and payment details."""
    if body.action not in ("confirm", "decline"):
        raise HTTPException(status_code=400, detail="action must be 'confirm' or 'decline'.")

    with db() as conn:
        row = conn.execute(
            "SELECT * FROM orders WHERE id = ? AND vendor_id = ?",
            (order_id, vendor_id),
        ).fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Order not found.")
        if row["status"] not in ("pending", "payment_rejected"):
            raise HTTPException(
                status_code=409,
                detail=f"Order in '{row['status']}' state cannot be confirmed or declined.",
            )

        now = utc_now()
        if body.action == "decline":
            conn.execute(
                """
                UPDATE orders SET
                  status = 'cancelled',
                  payment_rejection_reason = ?,
                  vendor_notes = ?,
                  updated_at = ?
                WHERE id = ?
                """,
                (body.declineReason or "Vendor declined the order",
                 body.vendorNotes, now, order_id),
            )
        else:
            conn.execute(
                """
                UPDATE orders SET
                  status = 'confirmed',
                  final_price_cents = ?,
                  delivery_method = ?,
                  delivery_area = ?,
                  collection_point = ?,
                  turnaround_time = ?,
                  payment_instructions = ?,
                  delivery_instructions = ?,
                  vendor_notes = ?,
                  updated_at = ?
                WHERE id = ?
                """,
                (
                    body.finalPriceCents,
                    body.deliveryMethod,
                    body.deliveryArea,
                    body.collectionPoint,
                    body.turnaroundTime,
                    body.paymentInstructions,
                    body.deliveryInstructions,
                    body.vendorNotes,
                    now,
                    order_id,
                ),
            )
        updated = conn.execute("SELECT * FROM orders WHERE id = ?", (order_id,)).fetchone()

    action_label = "confirmed" if body.action == "confirm" else "declined"
    audit(
        f"order_{action_label}",
        actor_type="vendor",
        actor_id=vendor_id,
        target_type="order",
        target_id=order_id,
        details={
            "action": body.action,
            "finalPriceCents": body.finalPriceCents,
            "deliveryMethod": body.deliveryMethod,
        },
    )
    return {"order": order_payload(updated)}


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

    signatures = {
        "image/jpeg": (b"\xff\xd8\xff", "jpg"),
        "image/png": (b"\x89PNG\r\n\x1a\n", "png"),
        "image/webp": (b"RIFF", "webp"),
        "image/gif": (b"GIF87a", "gif"),
    }
    content = file.file.read(5 * 1024 * 1024 + 1)
    signature, ext = signatures[file.content_type]
    if not content.startswith(signature):
        raise HTTPException(status_code=400, detail="File content does not match its declared image type.")
    filename = f"{product_id}_{uuid.uuid4().hex[:8]}.{ext}"
    dest = UPLOAD_DIR / filename
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


# ── Admin ────────────────────────────────────────────────────────────

ADMIN_TOKEN = os.getenv("ADMIN_TOKEN", "")


def require_admin(authorization: Optional[str] = Header(default=None)) -> str:
    """Simple bearer-token admin auth. In production, swap for a proper admin JWT."""
    if not ADMIN_TOKEN:
        raise HTTPException(status_code=503, detail="Admin access not configured.")
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Admin authentication required.")
    if authorization[7:] != ADMIN_TOKEN:
        raise HTTPException(status_code=403, detail="Invalid admin token.")
    return "admin"


def audit(action: str, actor_type: str = "system", actor_id: str = "",
          target_type: str = "", target_id: str = "", details: dict | None = None) -> None:
    """Write an immutable audit event."""
    with db() as conn:
        conn.execute(
            "INSERT INTO audit_events (action, actor_type, actor_id, target_type, target_id, details, created_at)"
            " VALUES (?, ?, ?, ?, ?, ?, ?)",
            (action, actor_type, actor_id, target_type, target_id,
             json.dumps(details or {}), utc_now()),
        )


class AdminTokenBody(BaseModel):
    reference: str
    note: str = ""


class AdminLoginBody(BaseModel):
    token: str


@app.post("/api/admin/login")
def admin_login(body: AdminLoginBody):
    """Validate the admin token and return a session."""
    if not ADMIN_TOKEN:
        raise HTTPException(status_code=503, detail="Admin access not configured.")
    if body.token != ADMIN_TOKEN:
        raise HTTPException(status_code=401, detail="Invalid admin token.")
    return {"ok": True}


@app.get("/api/admin/orders")
def admin_orders(
    status: Optional[str] = None,
    vendor_id: Optional[str] = None,
    q: Optional[str] = None,
    limit: int = 50,
    _admin: str = Depends(require_admin),
):
    conditions = ["1=1"]
    params: list = []
    if status:
        conditions.append("status = ?")
        params.append(status)
    if vendor_id:
        conditions.append("vendor_id = ?")
        params.append(vendor_id)
    if q:
        conditions.append("(reference LIKE ? OR id LIKE ?)")
        params.extend([f"%{q}%", f"%{q}%"])
    where = " AND ".join(conditions)
    with db() as conn:
        rows = conn.execute(
            f"SELECT * FROM orders WHERE {where} ORDER BY created_at DESC LIMIT ?",
            (*params, min(limit, 200)),
        ).fetchall()
    return {"orders": [order_payload(row) for row in rows]}


@app.get("/api/admin/vendors")
def admin_vendors(_admin: str = Depends(require_admin)):
    with db() as conn:
        rows = conn.execute("SELECT * FROM vendors ORDER BY name ASC").fetchall()
    return {"vendors": [row_to_vendor(row) for row in rows]}


@app.get("/api/admin/remedy-submissions")
def admin_remedy_submissions(
    status: str = "pending",
    limit: int = 50,
    _admin: str = Depends(require_admin),
):
    if status not in {"pending", "approved", "rejected", "all"}:
        raise HTTPException(status_code=400, detail="Invalid submission status.")
    with db() as conn:
        if status == "all":
            rows = conn.execute(
                "SELECT * FROM remedy_submissions ORDER BY created_at DESC LIMIT ?",
                (min(limit, 200),),
            ).fetchall()
        else:
            rows = conn.execute(
                """
                SELECT * FROM remedy_submissions
                WHERE status = ?
                ORDER BY created_at DESC
                LIMIT ?
                """,
                (status, min(limit, 200)),
            ).fetchall()
    return {"submissions": [row_to_remedy_submission(row) for row in rows]}


@app.patch("/api/admin/remedy-submissions/{submission_id}")
def moderate_remedy_submission(
    submission_id: str,
    body: RemedyModerationBody,
    _admin: str = Depends(require_admin),
):
    if body.action not in {"approve", "reject"}:
        raise HTTPException(status_code=400, detail="Action must be approve or reject.")
    status = "approved" if body.action == "approve" else "rejected"
    now = utc_now()
    with db() as conn:
        row = conn.execute(
            "SELECT * FROM remedy_submissions WHERE id = ?",
            (submission_id,),
        ).fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Remedy submission not found.")
        if row["status"] != "pending":
            raise HTTPException(status_code=409, detail="Submission was already reviewed.")
        conn.execute(
            """
            UPDATE remedy_submissions
            SET status = ?, moderation_note = ?, reviewed_at = ?, reviewed_by = ?
            WHERE id = ?
            """,
            (status, body.moderationNote.strip(), now, "admin", submission_id),
        )
        updated = conn.execute(
            "SELECT * FROM remedy_submissions WHERE id = ?",
            (submission_id,),
        ).fetchone()
    audit(
        f"remedy_{status}",
        actor_type="admin",
        actor_id="admin",
        target_type="remedy_submission",
        target_id=submission_id,
        details={"moderationNote": body.moderationNote.strip()},
    )
    return {"submission": row_to_remedy_submission(updated)}


@app.get("/api/admin/metrics")
def admin_metrics(_admin: str = Depends(require_admin)):
    with db() as conn:
        vendors = conn.execute("SELECT COUNT(*) FROM vendors").fetchone()[0]
        products = conn.execute("SELECT COUNT(*) FROM products WHERE deleted_at IS NULL").fetchone()[0]
        orders = conn.execute("SELECT COUNT(*) FROM orders").fetchone()[0]
        pending_proof = conn.execute("SELECT COUNT(*) FROM orders WHERE status = 'payment_proof_submitted'").fetchone()[0]
        pending_activation = conn.execute("SELECT COUNT(*) FROM activation_tokens WHERE redeemed_at IS NULL").fetchone()[0]
        premium_devices = conn.execute("SELECT COUNT(*) FROM subscriptions WHERE is_premium = 1").fetchone()[0]
        total_devices = conn.execute("SELECT COUNT(*) FROM devices").fetchone()[0]
        reviews = conn.execute("SELECT COUNT(*) FROM reviews").fetchone()[0]
    return {
        "vendors": vendors,
        "products": products,
        "totalOrders": orders,
        "pendingPaymentProofs": pending_proof,
        "pendingActivations": pending_activation,
        "premiumDevices": premium_devices,
        "totalDevices": total_devices,
        "reviews": reviews,
    }


@app.post("/api/admin/activation-tokens")
def admin_issue_token(body: AdminTokenBody, _admin: str = Depends(require_admin)):
    """Issue a single-use Plus activation token after EcoCash payment verification."""
    import secrets as _secrets
    token = f"USIZO-{_secrets.token_urlsafe(18).upper()}"
    now = utc_now()
    with db() as conn:
        conn.execute(
            "INSERT INTO activation_tokens (token_hash, reference, created_at) VALUES (?, ?, ?)",
            (token_digest(token), body.reference.strip(), now),
        )
    audit("activation_token_issued", actor_type="admin", actor_id="admin",
          target_type="activation_token", details={"reference": body.reference})
    return {"token": token, "reference": body.reference, "createdAt": now}


@app.delete("/api/admin/reviews/{review_id}")
def admin_delete_review(review_id: str, _admin: str = Depends(require_admin)):
    with db() as conn:
        row = conn.execute("SELECT * FROM reviews WHERE id = ?", (review_id,)).fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Review not found.")
        conn.execute("DELETE FROM reviews WHERE id = ?", (review_id,))
        agg = conn.execute(
            "SELECT AVG(rating) as avg_rating, COUNT(*) as cnt FROM reviews WHERE vendor_id = ?",
            (row["vendor_id"],),
        ).fetchone()
        conn.execute(
            "UPDATE vendors SET rating = ?, review_count = ? WHERE id = ?",
            (round(agg["avg_rating"], 1) if agg["avg_rating"] else 0, agg["cnt"], row["vendor_id"]),
        )
    audit("review_deleted", actor_type="admin", actor_id="admin",
          target_type="review", target_id=review_id)
    return {"ok": True}


@app.get("/api/admin/audit")
def admin_audit(limit: int = 100, _admin: str = Depends(require_admin)):
    with db() as conn:
        rows = conn.execute(
            "SELECT * FROM audit_events ORDER BY created_at DESC LIMIT ?",
            (min(limit, 500),),
        ).fetchall()
    return {
        "events": [
            {
                "id": row["id"],
                "action": row["action"],
                "actorType": row["actor_type"],
                "actorId": row["actor_id"],
                "targetType": row["target_type"],
                "targetId": row["target_id"],
                "details": json.loads(row["details"] or "{}"),
                "createdAt": row["created_at"],
            }
            for row in rows
        ]
    }
