const express = require('express');
const { v4: uuidv4 } = require('uuid');
const db = require('../db');
const { rowToProduct } = require('../utils');

const router = express.Router();
const now = () => new Date().toISOString();

function ensureDevice(deviceId) {
  const existing = db.prepare('SELECT id FROM devices WHERE id = ?').get(deviceId);
  if (existing) return;
  const createdAt = now();
  db.prepare('INSERT INTO devices (id, created_at, updated_at) VALUES (?, ?, ?)').run(
    deviceId,
    createdAt,
    createdAt,
  );
  db.prepare(
    'INSERT INTO device_profiles (device_id, updated_at) VALUES (?, ?)',
  ).run(deviceId, createdAt);
  db.prepare(
    'INSERT INTO subscriptions (device_id, is_premium, checks_used, updated_at) VALUES (?, 0, 0, ?)',
  ).run(deviceId, createdAt);
}

router.post('/register', (req, res) => {
  const { deviceId } = req.body || {};
  const id = deviceId || uuidv4();
  ensureDevice(id);
  const updatedAt = now();
  db.prepare('UPDATE devices SET updated_at = ? WHERE id = ?').run(updatedAt, id);
  res.json({ deviceId: id });
});

router.get('/:deviceId/state', (req, res) => {
  ensureDevice(req.params.deviceId);
  const profile = db
    .prepare('SELECT * FROM device_profiles WHERE device_id = ?')
    .get(req.params.deviceId);
  const subscription = db
    .prepare('SELECT * FROM subscriptions WHERE device_id = ?')
    .get(req.params.deviceId);
  const orders = db
    .prepare(
      'SELECT * FROM orders WHERE device_id = ? ORDER BY created_at DESC LIMIT 50',
    )
    .all(req.params.deviceId)
    .map((row) => ({
      id: row.id,
      vendorId: row.vendor_id,
      reference: row.reference,
      totalCents: row.total_cents,
      status: row.status,
      items: JSON.parse(row.items),
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    }));

  res.json({
    profile: {
      name: profile.name,
      email: profile.email,
      allergies: profile.allergies,
      emergencyContact: profile.emergency_contact,
      updatedAt: profile.updated_at,
    },
    subscription: {
      isPremium: subscription.is_premium === 1,
      checksUsed: subscription.checks_used,
      updatedAt: subscription.updated_at,
    },
    orders,
    serverTime: now(),
  });
});

router.put('/:deviceId/profile', (req, res) => {
  ensureDevice(req.params.deviceId);
  const {
    name = '',
    email = '',
    allergies = '',
    emergencyContact = '',
  } = req.body || {};
  const updatedAt = now();

  db.prepare(`
    UPDATE device_profiles SET
      name = ?, email = ?, allergies = ?, emergency_contact = ?, updated_at = ?
    WHERE device_id = ?
  `).run(
    String(name).trim(),
    String(email).trim(),
    String(allergies).trim(),
    String(emergencyContact).trim(),
    updatedAt,
    req.params.deviceId,
  );

  db.prepare('UPDATE devices SET updated_at = ? WHERE id = ?').run(
    updatedAt,
    req.params.deviceId,
  );

  res.json({
    profile: { name, email, allergies, emergencyContact, updatedAt },
  });
});

router.post('/:deviceId/check', (req, res) => {
  ensureDevice(req.params.deviceId);
  const sub = db
    .prepare('SELECT * FROM subscriptions WHERE device_id = ?')
    .get(req.params.deviceId);

  const isPremium = sub.is_premium === 1;
  if (!isPremium && sub.checks_used >= 3) {
    return res.json({
      allowed: false,
      isPremium: false,
      checksUsed: sub.checks_used,
      checksRemaining: 0,
    });
  }

  const updatedAt = now();
  let checksUsed = sub.checks_used;
  if (!isPremium) {
    checksUsed += 1;
    db.prepare(
      'UPDATE subscriptions SET checks_used = ?, updated_at = ? WHERE device_id = ?',
    ).run(checksUsed, updatedAt, req.params.deviceId);
  }

  res.json({
    allowed: true,
    isPremium,
    checksUsed,
    checksRemaining: isPremium ? 999 : Math.max(0, 3 - checksUsed),
  });
});

// Simple token validation matching Flutter TokenValidator
function isValidToken(token) {
  const prefix = 'USIZO-';
  const clean = String(token || '').trim().toUpperCase();
  if (!clean.startsWith(prefix)) return false;
  const body = clean.slice(prefix.length);
  if (body.length !== 8) return false;
  const data = body.slice(0, 6);
  const check = body.slice(6, 8);
  const secret = 'USIZOAI2026';
  let hash = 0;
  for (let i = 0; i < data.length; i++) {
    hash = ((hash << 5) + hash + data.charCodeAt(i)) & 0xff;
  }
  for (let i = 0; i < secret.length; i++) {
    hash = ((hash << 3) + hash + secret.charCodeAt(i)) & 0xff;
  }
  const expected = hash.toString(16).toUpperCase().padStart(2, '0');
  return check === expected;
}

router.post('/:deviceId/subscriptions/activate', (req, res) => {
  ensureDevice(req.params.deviceId);
  const { token } = req.body || {};
  if (!isValidToken(token)) {
    return res.status(400).json({ error: 'Invalid activation token.' });
  }
  const updatedAt = now();
  db.prepare(
    'UPDATE subscriptions SET is_premium = 1, updated_at = ? WHERE device_id = ?',
  ).run(updatedAt, req.params.deviceId);
  res.json({ isPremium: true, updatedAt });
});

router.post('/:deviceId/orders', (req, res) => {
  ensureDevice(req.params.deviceId);
  const { id, vendorId, reference, totalCents, items, status = 'pending' } =
    req.body || {};

  if (!vendorId || !items?.length) {
    return res.status(400).json({ error: 'vendorId and items are required.' });
  }

  const orderId = id || `ORD-${uuidv4().slice(0, 8).toUpperCase()}`;
  const createdAt = now();
  const existing = db.prepare('SELECT id FROM orders WHERE id = ?').get(orderId);
  if (existing) {
    return res.json({ order: existing, duplicate: true });
  }

  db.prepare(`
    INSERT INTO orders (
      id, device_id, vendor_id, reference, total_cents, status, items, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
  `).run(
    orderId,
    req.params.deviceId,
    vendorId,
    reference || orderId,
    totalCents,
    status,
    JSON.stringify(items),
    createdAt,
    createdAt,
  );

  res.status(201).json({
    order: {
      id: orderId,
      vendorId,
      reference: reference || orderId,
      totalCents,
      status,
      items,
      createdAt,
      updatedAt: createdAt,
    },
  });
});

module.exports = router;
