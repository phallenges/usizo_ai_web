import json
import os
import hashlib
import sqlite3
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path

DB_PATH = Path(os.getenv("DATABASE_PATH", Path(__file__).parent.parent / "data" / "usizo.db"))


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def get_connection() -> sqlite3.Connection:
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(DB_PATH, timeout=10)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    conn.execute("PRAGMA journal_mode = WAL")
    conn.execute("PRAGMA busy_timeout = 10000")
    return conn


@contextmanager
def db():
    conn = get_connection()
    try:
        yield conn
        conn.commit()
    finally:
        conn.close()


def init_schema() -> None:
    with db() as conn:
        conn.executescript(
            """
            CREATE TABLE IF NOT EXISTS vendors (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              location TEXT NOT NULL,
              description TEXT DEFAULT '',
              phone TEXT NOT NULL UNIQUE,
              ecocash_number TEXT DEFAULT '',
              whatsapp TEXT DEFAULT '',
              rating REAL DEFAULT 0,
              review_count INTEGER DEFAULT 0,
              lat REAL,
              lng REAL,
              pin_hash TEXT NOT NULL,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS products (
              id TEXT PRIMARY KEY,
              vendor_id TEXT NOT NULL REFERENCES vendors(id),
              name TEXT NOT NULL,
              price_cents INTEGER NOT NULL,
              description TEXT DEFAULT '',
              category TEXT DEFAULT 'Herbal remedy',
              tags TEXT DEFAULT '[]',
              image_asset TEXT,
              in_stock INTEGER DEFAULT 1,
              can_buy_online INTEGER DEFAULT 0,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              deleted_at TEXT
            );

            CREATE TABLE IF NOT EXISTS devices (
              id TEXT PRIMARY KEY,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS device_profiles (
              device_id TEXT PRIMARY KEY REFERENCES devices(id),
              name TEXT DEFAULT '',
              email TEXT DEFAULT '',
              allergies TEXT DEFAULT '',
              emergency_contact TEXT DEFAULT '',
              updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS subscriptions (
              device_id TEXT PRIMARY KEY REFERENCES devices(id),
              is_premium INTEGER DEFAULT 0,
              checks_used INTEGER DEFAULT 0,
              updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS orders (
              id TEXT PRIMARY KEY,
              device_id TEXT NOT NULL REFERENCES devices(id),
              vendor_id TEXT NOT NULL,
              reference TEXT NOT NULL,
              total_cents INTEGER NOT NULL,
              status TEXT DEFAULT 'pending',
              items TEXT NOT NULL,
              payment_proof_path TEXT,
              payment_rejection_reason TEXT DEFAULT '',
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS reviews (
              id TEXT PRIMARY KEY,
              vendor_id TEXT NOT NULL REFERENCES vendors(id),
              device_id TEXT NOT NULL,
              rating INTEGER NOT NULL CHECK(rating >= 1 AND rating <= 5),
              comment TEXT DEFAULT '',
              created_at TEXT NOT NULL
            );

            -- Tokens are issued only after a manual EcoCash payment is verified.
            -- Store a digest, never the token itself, and make every token single-use.
            CREATE TABLE IF NOT EXISTS activation_tokens (
              token_hash TEXT PRIMARY KEY,
              reference TEXT NOT NULL UNIQUE,
              redeemed_by_device_id TEXT REFERENCES devices(id),
              created_at TEXT NOT NULL,
              redeemed_at TEXT
            );

            CREATE INDEX IF NOT EXISTS idx_products_vendor_active
              ON products(vendor_id, deleted_at, updated_at);
            CREATE INDEX IF NOT EXISTS idx_orders_vendor_created
              ON orders(vendor_id, created_at DESC);
            CREATE INDEX IF NOT EXISTS idx_orders_device_created
              ON orders(device_id, created_at DESC);
            CREATE UNIQUE INDEX IF NOT EXISTS idx_reviews_vendor_device
              ON reviews(vendor_id, device_id);

            CREATE TABLE IF NOT EXISTS audit_events (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              action TEXT NOT NULL,
              actor_type TEXT NOT NULL DEFAULT 'system',
              actor_id TEXT DEFAULT '',
              target_type TEXT DEFAULT '',
              target_id TEXT DEFAULT '',
              details TEXT DEFAULT '{}',
              created_at TEXT NOT NULL
            );

            CREATE INDEX IF NOT EXISTS idx_audit_created
              ON audit_events(created_at DESC);
            """
        )
        # SQLite CREATE TABLE IF NOT EXISTS does not add fields to databases
        # created by older app versions, so apply safe additive migrations here.
        vendor_columns = {row["name"] for row in conn.execute("PRAGMA table_info(vendors)")}
        if "ecocash_number" not in vendor_columns:
            conn.execute("ALTER TABLE vendors ADD COLUMN ecocash_number TEXT DEFAULT ''")
        order_columns = {row["name"] for row in conn.execute("PRAGMA table_info(orders)")}
        if "payment_proof_path" not in order_columns:
            conn.execute("ALTER TABLE orders ADD COLUMN payment_proof_path TEXT")
        if "payment_rejection_reason" not in order_columns:
            conn.execute(
                "ALTER TABLE orders ADD COLUMN payment_rejection_reason TEXT DEFAULT ''"
            )
        if "final_price_cents" not in order_columns:
            conn.execute("ALTER TABLE orders ADD COLUMN final_price_cents INTEGER")
        if "delivery_method" not in order_columns:
            conn.execute("ALTER TABLE orders ADD COLUMN delivery_method TEXT DEFAULT ''")
        if "delivery_area" not in order_columns:
            conn.execute("ALTER TABLE orders ADD COLUMN delivery_area TEXT DEFAULT ''")
        if "collection_point" not in order_columns:
            conn.execute("ALTER TABLE orders ADD COLUMN collection_point TEXT DEFAULT ''")
        if "turnaround_time" not in order_columns:
            conn.execute("ALTER TABLE orders ADD COLUMN turnaround_time TEXT DEFAULT ''")
        if "payment_instructions" not in order_columns:
            conn.execute("ALTER TABLE orders ADD COLUMN payment_instructions TEXT DEFAULT ''")
        if "delivery_instructions" not in order_columns:
            conn.execute("ALTER TABLE orders ADD COLUMN delivery_instructions TEXT DEFAULT ''")
        if "vendor_notes" not in order_columns:
            conn.execute("ALTER TABLE orders ADD COLUMN vendor_notes TEXT DEFAULT ''")


def token_digest(token: str) -> str:
    """Return the database-safe digest used for manual activation tokens."""
    return hashlib.sha256(token.strip().upper().encode("utf-8")).hexdigest()


def row_to_vendor(row: sqlite3.Row) -> dict:
    return {
        "id": row["id"],
        "name": row["name"],
        "location": row["location"],
        "description": row["description"],
        "phone": row["phone"],
        "ecocashNumber": row["ecocash_number"],
        "whatsapp": row["whatsapp"],
        "rating": row["rating"],
        "reviewCount": row["review_count"],
        "lat": row["lat"],
        "lng": row["lng"],
    }


def row_to_product(row: sqlite3.Row) -> dict:
    return {
        "id": row["id"],
        "vendorId": row["vendor_id"],
        "name": row["name"],
        "priceCents": row["price_cents"],
        "description": row["description"],
        "category": row["category"],
        "tags": json.loads(row["tags"] or "[]"),
        "imageAsset": row["image_asset"],
        "inStock": row["in_stock"] == 1,
        "canBuyOnline": row["can_buy_online"] == 1,
        "updatedAt": row["updated_at"],
    }
