const express = require('express');
const db = require('../db');
const { rowToVendor, rowToProduct } = require('../utils');

const router = express.Router();
const now = () => new Date().toISOString();

router.get('/catalog', (req, res) => {
  const since = req.query.since || '1970-01-01T00:00:00.000Z';

  const vendors = db
    .prepare('SELECT * FROM vendors WHERE updated_at > ? ORDER BY updated_at ASC')
    .all(since)
    .map(rowToVendor);

  const products = db
    .prepare(
      `SELECT * FROM products
       WHERE updated_at > ? AND deleted_at IS NULL
       ORDER BY updated_at ASC`,
    )
    .all(since)
    .map(rowToProduct);

  const deletedProducts = db
    .prepare(
      'SELECT id, deleted_at AS deletedAt FROM products WHERE deleted_at > ?',
    )
    .all(since);

  const serverTime = now();
  res.json({
    vendors,
    products,
    deletedProductIds: deletedProducts.map((row) => row.id),
    serverTime,
  });
});

router.get('/full-catalog', (_req, res) => {
  const vendors = db
    .prepare('SELECT * FROM vendors ORDER BY name ASC')
    .all()
    .map(rowToVendor);
  const products = db
    .prepare('SELECT * FROM products WHERE deleted_at IS NULL ORDER BY name ASC')
    .all()
    .map(rowToProduct);
  res.json({ vendors, products, serverTime: now() });
});

module.exports = router;
