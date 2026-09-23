import hashlib
import json
import os
import re
import sqlite3
from contextlib import contextmanager
from pathlib import Path
from typing import Any

from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL", "").strip()
DATABASE_PATH = Path(
    os.getenv("DATABASE_PATH", Path(__file__).parent.parent / "data" / "usizo.db")
)
_postgres_pool = None


def utc_now() -> str:
    from datetime import datetime, timezone

    return datetime.now(timezone.utc).isoformat()


def _is_postgres() -> bool:
    return DATABASE_URL.startswith(("postgres://", "postgresql://"))


def _qmark_to_postgres(sql: str) -> str:
    return re.sub(r"\?", "%s", sql)


class PostgresConnection:
    def __init__(self, raw):
        self.raw = raw

    def execute(self, sql: str, params=()):
        return self.raw.execute(_qmark_to_postgres(sql), params)

    def executescript(self, script: str):
        for statement in script.split(";"):
            statement = statement.strip()
            if statement:
                self.execute(statement)


class HybridRow(dict):
    """Mapping row that also preserves SQLite-style integer indexing."""

    def __getitem__(self, key):
        if isinstance(key, int):
            return tuple(self.values())[key]
        return super().__getitem__(key)


def _hybrid_row_factory(cursor):
    if cursor.description is None:
        return lambda values: None

    columns = [column.name for column in cursor.description]

    def make_row(values):
        return HybridRow(zip(columns, values))

    return make_row


def _get_postgres_pool():
    global _postgres_pool
    if _postgres_pool is None:
        from psycopg_pool import ConnectionPool

        _postgres_pool = ConnectionPool(
            conninfo=DATABASE_URL,
            min_size=int(os.getenv("DATABASE_POOL_MIN", "1")),
            max_size=int(os.getenv("DATABASE_POOL_MAX", "10")),
            kwargs={"row_factory": _hybrid_row_factory},
            open=True,
            timeout=10,
        )
    return _postgres_pool


@contextmanager
def db():
    if _is_postgres():
        pool = _get_postgres_pool()
        connection = pool.getconn()
        try:
            wrapped = PostgresConnection(connection)
            yield wrapped
            connection.commit()
        except Exception:
            connection.rollback()
            raise
        finally:
            pool.putconn(connection)
        return

    if os.getenv("ENVIRONMENT", "development").lower() == "production":
        raise RuntimeError("DATABASE_URL must be a PostgreSQL URL in production.")

    DATABASE_PATH.parent.mkdir(parents=True, exist_ok=True)
    connection = sqlite3.connect(DATABASE_PATH, timeout=10)
    connection.row_factory = sqlite3.Row
    connection.execute("PRAGMA foreign_keys = ON")
    connection.execute("PRAGMA journal_mode = WAL")
    connection.execute("PRAGMA busy_timeout = 10000")
    try:
        yield connection
        connection.commit()
    except Exception:
        connection.rollback()
        raise
    finally:
        connection.close()


SCHEMA = """
CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  email TEXT UNIQUE,
  phone TEXT UNIQUE,
  password_hash TEXT NOT NULL,
  name TEXT NOT NULL,
  allergies TEXT DEFAULT '',
  emergency_contact TEXT DEFAULT '',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
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
  user_id TEXT REFERENCES users(id),
  auth_token_hash TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS device_profiles (
  device_id TEXT PRIMARY KEY REFERENCES devices(id),
  name TEXT DEFAULT '',
  email TEXT DEFAULT '',
  allergies TEXT DEFAULT '',
  medical_conditions TEXT DEFAULT '',
  current_medications TEXT DEFAULT '',
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
  final_price_cents INTEGER,
  delivery_method TEXT DEFAULT '',
  delivery_area TEXT DEFAULT '',
  collection_point TEXT DEFAULT '',
  turnaround_time TEXT DEFAULT '',
  payment_instructions TEXT DEFAULT '',
  delivery_instructions TEXT DEFAULT '',
  vendor_notes TEXT DEFAULT '',
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
CREATE TABLE IF NOT EXISTS remedy_submissions (
  id TEXT PRIMARY KEY,
  device_id TEXT NOT NULL REFERENCES devices(id),
  name TEXT NOT NULL,
  scientific_name TEXT DEFAULT '',
  local_names TEXT DEFAULT '{}',
  category TEXT NOT NULL,
  description TEXT NOT NULL,
  usage TEXT NOT NULL,
  preparation TEXT NOT NULL,
  dosage TEXT NOT NULL,
  warning TEXT NOT NULL,
  evidence_source TEXT NOT NULL,
  study_url TEXT DEFAULT '',
  tags TEXT DEFAULT '[]',
  status TEXT NOT NULL DEFAULT 'pending',
  moderation_note TEXT DEFAULT '',
  created_at TEXT NOT NULL,
  reviewed_at TEXT,
  reviewed_by TEXT DEFAULT ''
);
CREATE TABLE IF NOT EXISTS activation_tokens (
  token_hash TEXT PRIMARY KEY,
  reference TEXT NOT NULL UNIQUE,
  redeemed_by_device_id TEXT REFERENCES devices(id),
  created_at TEXT NOT NULL,
  redeemed_at TEXT
);
CREATE TABLE IF NOT EXISTS plus_payment_submissions (
  id TEXT PRIMARY KEY,
  device_id TEXT NOT NULL REFERENCES devices(id),
  user_id TEXT REFERENCES users(id),
  merchant_reference TEXT NOT NULL,
  confirmation_message TEXT NOT NULL,
  delivery_email TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'pending',
  admin_note TEXT DEFAULT '',
  created_at TEXT NOT NULL,
  reviewed_at TEXT,
  reviewed_by TEXT DEFAULT ''
);
CREATE INDEX IF NOT EXISTS idx_plus_payments_status_created
  ON plus_payment_submissions(status, created_at DESC);
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
CREATE INDEX IF NOT EXISTS idx_products_vendor_active
  ON products(vendor_id, deleted_at, updated_at);
CREATE INDEX IF NOT EXISTS idx_orders_vendor_created
  ON orders(vendor_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_device_created
  ON orders(device_id, created_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS idx_reviews_vendor_device
  ON reviews(vendor_id, device_id);
CREATE INDEX IF NOT EXISTS idx_remedy_submissions_status_created
  ON remedy_submissions(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_created
  ON audit_events(created_at DESC);
"""


def _postgres_schema(conn: PostgresConnection) -> None:
    conn.execute("SELECT pg_advisory_lock(837421)")
    try:
        conn.executescript(SCHEMA.replace("INTEGER PRIMARY KEY AUTOINCREMENT", "BIGSERIAL PRIMARY KEY"))
        conn.execute("ALTER TABLE vendors ADD COLUMN IF NOT EXISTS ecocash_number TEXT DEFAULT ''")
        conn.execute("ALTER TABLE orders ADD COLUMN IF NOT EXISTS payment_proof_path TEXT")
        conn.execute("ALTER TABLE orders ADD COLUMN IF NOT EXISTS payment_rejection_reason TEXT DEFAULT ''")
        conn.execute("ALTER TABLE orders ADD COLUMN IF NOT EXISTS final_price_cents INTEGER")
        conn.execute("ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivery_method TEXT DEFAULT ''")
        conn.execute("ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivery_area TEXT DEFAULT ''")
        conn.execute("ALTER TABLE orders ADD COLUMN IF NOT EXISTS collection_point TEXT DEFAULT ''")
        conn.execute("ALTER TABLE orders ADD COLUMN IF NOT EXISTS turnaround_time TEXT DEFAULT ''")
        conn.execute("ALTER TABLE orders ADD COLUMN IF NOT EXISTS payment_instructions TEXT DEFAULT ''")
        conn.execute("ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivery_instructions TEXT DEFAULT ''")
        conn.execute("ALTER TABLE orders ADD COLUMN IF NOT EXISTS vendor_notes TEXT DEFAULT ''")
        conn.execute("ALTER TABLE devices ADD COLUMN IF NOT EXISTS user_id TEXT REFERENCES users(id)")
        conn.execute("ALTER TABLE devices ADD COLUMN IF NOT EXISTS auth_token_hash TEXT")
        conn.execute("ALTER TABLE device_profiles ADD COLUMN IF NOT EXISTS medical_conditions TEXT DEFAULT ''")
        conn.execute("ALTER TABLE device_profiles ADD COLUMN IF NOT EXISTS current_medications TEXT DEFAULT ''")
        conn.execute("ALTER TABLE plus_payment_submissions ADD COLUMN IF NOT EXISTS delivery_email TEXT DEFAULT ''")
        conn.execute("CREATE INDEX IF NOT EXISTS idx_devices_user ON devices(user_id)")
    except Exception:
        conn.raw.rollback()
        raise
    finally:
        conn.execute("SELECT pg_advisory_unlock(837421)")


def init_schema() -> None:
    if _is_postgres():
        with db() as conn:
            _postgres_schema(conn)
        return

    with db() as conn:
        conn.executescript(SCHEMA)
        vendor_columns = {row["name"] for row in conn.execute("PRAGMA table_info(vendors)")}
        if "ecocash_number" not in vendor_columns:
            conn.execute("ALTER TABLE vendors ADD COLUMN ecocash_number TEXT DEFAULT ''")
        order_columns = {row["name"] for row in conn.execute("PRAGMA table_info(orders)")}
        for column, definition in {
            "payment_proof_path": "TEXT",
            "payment_rejection_reason": "TEXT DEFAULT ''",
            "final_price_cents": "INTEGER",
            "delivery_method": "TEXT DEFAULT ''",
            "delivery_area": "TEXT DEFAULT ''",
            "collection_point": "TEXT DEFAULT ''",
            "turnaround_time": "TEXT DEFAULT ''",
            "payment_instructions": "TEXT DEFAULT ''",
            "delivery_instructions": "TEXT DEFAULT ''",
            "vendor_notes": "TEXT DEFAULT ''",
        }.items():
            if column not in order_columns:
                conn.execute(f"ALTER TABLE orders ADD COLUMN {column} {definition}")
        device_columns = {row["name"] for row in conn.execute("PRAGMA table_info(devices)")}
        if "user_id" not in device_columns:
            conn.execute("ALTER TABLE devices ADD COLUMN user_id TEXT REFERENCES users(id)")
        if "auth_token_hash" not in device_columns:
            conn.execute("ALTER TABLE devices ADD COLUMN auth_token_hash TEXT")
        profile_columns = {
            row["name"] for row in conn.execute("PRAGMA table_info(device_profiles)")
        }
        for column in ("medical_conditions", "current_medications"):
            if column not in profile_columns:
                conn.execute(
                    f"ALTER TABLE device_profiles ADD COLUMN {column} TEXT DEFAULT ''"
                )
        plus_payment_columns = {
            row["name"]
            for row in conn.execute("PRAGMA table_info(plus_payment_submissions)")
        }
        if "delivery_email" not in plus_payment_columns:
            conn.execute(
                "ALTER TABLE plus_payment_submissions ADD COLUMN delivery_email TEXT DEFAULT ''"
            )
        conn.execute("CREATE INDEX IF NOT EXISTS idx_devices_user ON devices(user_id)")


def token_digest(token: str) -> str:
    return hashlib.sha256(token.strip().upper().encode("utf-8")).hexdigest()


def device_token_digest(token: str) -> str:
    """Hash a device auth token.

    Unlike token_digest, the value is case-sensitive: device tokens are
    base64url strings where the exact casing is part of the secret.
    """
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def row_to_vendor(row: Any) -> dict:
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


def row_to_product(row: Any) -> dict:
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
