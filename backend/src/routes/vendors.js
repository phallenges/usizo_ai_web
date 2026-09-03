const express = require('express');
const bcrypt = require('bcryptjs');
const { v4: uuidv4 } = require('uuid');
const db = require('../db');
const {
  signVendorToken,
  requireVendor,
  normalizePhone,
  rowToVendor,
  rowToProduct,
} = require('../utils');

const router = express.Router();
const now = () => new Date().toISOString();

router.post('/register', (req, res) => {
  const {
    businessName,
    location,
    phone,
    pin,
    whatsapp = '',
    description = '',
  } = req.body || {};

  if (!businessName?.trim()) {
    return res.status(400).json({ error: 'Business name is required.' });
  }
  if (!location?.trim()) {
    return res.status(400).json({ error: 'Location is required.' });
  }
  if (!phone?.trim()) {
    return res.status(400).json({ error: 'Phone number is required.' });
  }
  if (!pin || String(pin).length < 4) {
    return res.status(400).json({ error: 'PIN must be at least 4 digits.' });
  }

  const normalizedPhone = normalizePhone(phone);
  const existing = db
    .prepare('SELECT id FROM vendors WHERE phone = ? OR phone = ?')
    .get(phone.trim(), normalizedPhone);
  if (existing) {
    return res.status(409).json({ error: 'Phone number already registered.' });
  }

  const id = `vendor-${uuidv4().slice(0, 8)}`;
  const createdAt = now();
  const pinHash = bcrypt.hashSync(String(pin), 10);

  db.prepare(`
    INSERT INTO vendors (
      id, name, location, description, phone, whatsapp,
      rating, review_count, pin_hash, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, 0, 0, ?, ?, ?)
  `).run(
    id,
    businessName.trim(),
    location.trim(),
    description.trim(),
    phone.trim(),
    whatsapp.trim() || phone.trim(),
    pinHash,
    createdAt,
    createdAt,
  );

  const vendor = rowToVendor(
    db.prepare('SELECT * FROM vendors WHERE id = ?').get(id),
  );
  const token = signVendorToken(id);
  res.status(201).json({ vendor, token });
});

router.post('/login', (req, res) => {
  const { phone, pin } = req.body || {};
  if (!phone || !pin) {
    return res.status(400).json({ error: 'Phone and PIN are required.' });
  }

  const normalized = normalizePhone(phone);
  const row = db
    .prepare('SELECT * FROM vendors WHERE phone = ? OR phone = ?')
    .get(phone.trim(), normalized);
  if (!row || !bcrypt.compareSync(String(pin), row.pin_hash)) {
    return res.status(401).json({ error: 'Invalid phone number or PIN.' });
  }

  res.json({
    vendor: rowToVendor(row),
    token: signVendorToken(row.id),
  });
});

router.get('/me', requireVendor, (req, res) => {
  const row = db
    .prepare('SELECT * FROM vendors WHERE id = ?')
    .get(req.vendorId);
  if (!row) {
    return res.status(404).json({ error: 'Vendor not found.' });
  }
  res.json({ vendor: rowToVendor(row) });
});

router.patch('/me', requireVendor, (req, res) => {
  const row = db
    .prepare('SELECT * FROM vendors WHERE id = ?')
    .get(req.vendorId);
  if (!row) {
    return res.status(404).json({ error: 'Vendor not found.' });
  }

  const {
    name = row.name,
    location = row.location,
    description = row.description,
    phone = row.phone,
    whatsapp = row.whatsapp,
  } = req.body || {};

  const updatedAt = now();
  db.prepare(`
    UPDATE vendors SET
      name = ?, location = ?, description = ?, phone = ?, whatsapp = ?, updated_at = ?
    WHERE id = ?
  `).run(
    String(name).trim(),
    String(location).trim(),
    String(description).trim(),
    String(phone).trim(),
    String(whatsapp).trim(),
    updatedAt,
    req.vendorId,
  );

  const vendor = rowToVendor(
    db.prepare('SELECT * FROM vendors WHERE id = ?').get(req.vendorId),
  );
  res.json({ vendor });
});

router.get('/me/products', requireVendor, (req, res) => {
  const rows = db
    .prepare(
      'SELECT * FROM products WHERE vendor_id = ? AND deleted_at IS NULL ORDER BY updated_at DESC',
    )
    .all(req.vendorId);
  res.json({ products: rows.map(rowToProduct) });
});

router.post('/me/products', requireVendor, (req, res) => {
  const {
    name,
    description = '',
    category = 'Herbal remedy',
    priceCents,
    tags = [],
    inStock = true,
    canBuyOnline = false,
    imageAsset = null,
  } = req.body || {};

  if (!name?.trim()) {
    return res.status(400).json({ error: 'Product name is required.' });
  }
  if (!priceCents || priceCents <= 0) {
    return res.status(400).json({ error: 'Valid price is required.' });
  }

  const id = `prod-${uuidv4().slice(0, 8)}`;
  const createdAt = now();
  db.prepare(`
    INSERT INTO products (
      id, vendor_id, name, price_cents, description, category, tags,
      image_asset, in_stock, can_buy_online, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `).run(
    id,
    req.vendorId,
    name.trim(),
    priceCents,
    description.trim(),
    category.trim(),
    JSON.stringify(tags),
    imageAsset,
    inStock ? 1 : 0,
    canBuyOnline ? 1 : 0,
    createdAt,
    createdAt,
  );

  const product = rowToProduct(
    db.prepare('SELECT * FROM products WHERE id = ?').get(id),
  );
  res.status(201).json({ product });
});

router.patch('/me/products/:id', requireVendor, (req, res) => {
  const row = db
    .prepare('SELECT * FROM products WHERE id = ? AND vendor_id = ?')
    .get(req.params.id, req.vendorId);
  if (!row || row.deleted_at) {
    return res.status(404).json({ error: 'Product not found.' });
  }

  const updatedAt = now();
  const name = req.body.name ?? row.name;
  const description = req.body.description ?? row.description;
  const category = req.body.category ?? row.category;
  const priceCents = req.body.priceCents ?? row.price_cents;
  const tags = req.body.tags ?? JSON.parse(row.tags || '[]');
  const inStock = req.body.inStock ?? row.in_stock === 1;
  const canBuyOnline = req.body.canBuyOnline ?? row.can_buy_online === 1;

  db.prepare(`
    UPDATE products SET
      name = ?, description = ?, category = ?, price_cents = ?, tags = ?,
      in_stock = ?, can_buy_online = ?, updated_at = ?
    WHERE id = ?
  `).run(
    String(name).trim(),
    String(description).trim(),
    String(category).trim(),
    priceCents,
    JSON.stringify(tags),
    inStock ? 1 : 0,
    canBuyOnline ? 1 : 0,
    updatedAt,
    req.params.id,
  );

  const product = rowToProduct(
    db.prepare('SELECT * FROM products WHERE id = ?').get(req.params.id),
  );
  res.json({ product });
});

router.delete('/me/products/:id', requireVendor, (req, res) => {
  const row = db
    .prepare('SELECT * FROM products WHERE id = ? AND vendor_id = ?')
    .get(req.params.id, req.vendorId);
  if (!row || row.deleted_at) {
    return res.status(404).json({ error: 'Product not found.' });
  }

  const deletedAt = now();
  db.prepare(
    'UPDATE products SET deleted_at = ?, updated_at = ? WHERE id = ?',
  ).run(deletedAt, deletedAt, req.params.id);
  res.json({ ok: true, deletedAt });
});

module.exports = router;
