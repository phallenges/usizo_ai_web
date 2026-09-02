import json
import uuid
from pathlib import Path

import bcrypt

from .database import db, utc_now

ASSETS_DIR = Path(__file__).parent.parent.parent / "assets"


def seed_if_empty() -> None:
    with db() as conn:
        count = conn.execute("SELECT COUNT(*) FROM vendors").fetchone()[0]
        if count > 0:
            return

        vendors = json.loads((ASSETS_DIR / "vendors.json").read_text(encoding="utf-8"))
        products = json.loads((ASSETS_DIR / "products.json").read_text(encoding="utf-8"))
        pin_hash = bcrypt.hashpw(b"1234", bcrypt.gensalt()).decode("utf-8")
        created_at = utc_now()

        for vendor in vendors:
            conn.execute(
                """
                INSERT INTO vendors (
                  id, name, location, description, phone, whatsapp,
                  rating, review_count, lat, lng, pin_hash, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    vendor["id"],
                    vendor["name"],
                    vendor["location"],
                    vendor.get("description", ""),
                    vendor["phone"],
                    vendor.get("whatsapp", vendor["phone"]),
                    vendor.get("rating", 0),
                    vendor.get("reviewCount", 0),
                    vendor.get("lat"),
                    vendor.get("lng"),
                    pin_hash,
                    created_at,
                    created_at,
                ),
            )

        for product in products:
            conn.execute(
                """
                INSERT INTO products (
                  id, vendor_id, name, price_cents, description, category, tags,
                  image_asset, in_stock, can_buy_online, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    product["id"],
                    product["vendorId"],
                    product["name"],
                    product["priceCents"],
                    product.get("description", ""),
                    product.get("category", "Herbal remedy"),
                    json.dumps(product.get("tags", [])),
                    product.get("imageAsset"),
                    0 if product.get("inStock") is False else 1,
                    1 if product.get("canBuyOnline") else 0,
                    created_at,
                    created_at,
                ),
            )

        print(f"Seeded {len(vendors)} vendors and {len(products)} products.")
        print("Demo vendor PIN for seeded vendors: 1234")


def new_vendor_id() -> str:
    return f"vendor-{uuid.uuid4().hex[:8]}"


def new_product_id() -> str:
    return f"prod-{uuid.uuid4().hex[:8]}"


def new_order_id() -> str:
    return f"ORD-{uuid.uuid4().hex[:8].upper()}"


def new_review_id() -> str:
    return f"rev-{uuid.uuid4().hex[:8]}"
