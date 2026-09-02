import json
import os
import sqlite3
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path

DB_PATH = Path(os.getenv("DATABASE_PATH", Path(__file__).parent.parent / "data" / "usizo.db"))


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def get_connection() -> sqlite3.Connection:
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
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
            """
        )


def row_to_vendor(row: sqlite3.Row) -> dict:
    return {
        "id": row["id"],
        "name": row["name"],
        "location": row["location"],
        "description": row["description"],
        "phone": row["phone"],
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
