const express = require('express');
const db = require('../db');
const { rowToVendor, rowToProduct } = require('../utils');

const router = express.Router();

router.get('/', (_req, res) => {
  const rows = db
    .prepare('SELECT * FROM vendors ORDER BY name ASC')
    .all();
  res.json({ vendors: rows.map(rowToVendor) });
});

router.get('/products', (req, res) => {
  const { vendorId } = req.query;
  let rows;
  if (vendorId) {
    rows = db
      .prepare(
        `SELECT * FROM products
         WHERE vendor_id = ? AND deleted_at IS NULL
         ORDER BY updated_at DESC`,
      )
      .all(vendorId);
  } else {
    rows = db
      .prepare(
        'SELECT * FROM products WHERE deleted_at IS NULL ORDER BY updated_at DESC',
      )
      .all();
  }
  res.json({ products: rows.map(rowToProduct) });
});

module.exports = router;
