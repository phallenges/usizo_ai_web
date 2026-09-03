const Database = require('better-sqlite3');
const fs = require('fs');
const path = require('path');

const dbPath =
  process.env.DATABASE_PATH ||
  path.join(__dirname, '..', 'data', 'usizo.db');

fs.mkdirSync(path.dirname(dbPath), { recursive: true });

const db = new Database(dbPath);
db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');

function initSchema() {
  db.exec(`
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

    CREATE INDEX IF NOT EXISTS idx_products_vendor ON products(vendor_id);
    CREATE INDEX IF NOT EXISTS idx_products_updated ON products(updated_at);

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

    CREATE INDEX IF NOT EXISTS idx_orders_device ON orders(device_id);
    CREATE INDEX IF NOT EXISTS idx_orders_updated ON orders(updated_at);

    CREATE TABLE IF NOT EXISTS meta (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    );
  `);
}

initSchema();

module.exports = db;
