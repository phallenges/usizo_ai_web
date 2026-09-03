const fs = require('fs');
const path = require('path');
const bcrypt = require('bcryptjs');
const db = require('./db');

const assetsDir = path.join(__dirname, '..', '..', 'assets');
const now = () => new Date().toISOString();

function readJson(filename) {
  const filePath = path.join(assetsDir, filename);
  return JSON.parse(fs.readFileSync(filePath, 'utf8'));
}

function seed() {
  const vendorCount = db.prepare('SELECT COUNT(*) AS c FROM vendors').get().c;
  if (vendorCount > 0) {
    console.log('Database already seeded — skipping.');
    return;
  }

  const vendors = readJson('vendors.json');
  const products = readJson('products.json');
  const pinHash = bcrypt.hashSync('1234', 10);

  const insertVendor = db.prepare(`
    INSERT INTO vendors (
      id, name, location, description, phone, whatsapp,
      rating, review_count, lat, lng, pin_hash, created_at, updated_at
    ) VALUES (
      @id, @name, @location, @description, @phone, @whatsapp,
      @rating, @review_count, @lat, @lng, @pin_hash, @created_at, @updated_at
    )
  `);

  const insertProduct = db.prepare(`
    INSERT INTO products (
      id, vendor_id, name, price_cents, description, category, tags,
      image_asset, in_stock, can_buy_online, created_at, updated_at
    ) VALUES (
      @id, @vendor_id, @name, @price_cents, @description, @category, @tags,
      @image_asset, @in_stock, @can_buy_online, @created_at, @updated_at
    )
  `);

  const seedAt = now();
  const tx = db.transaction(() => {
    for (const vendor of vendors) {
      insertVendor.run({
        id: vendor.id,
        name: vendor.name,
        location: vendor.location,
        description: vendor.description || '',
        phone: vendor.phone,
        whatsapp: vendor.whatsapp || vendor.phone,
        rating: vendor.rating ?? 0,
        review_count: vendor.reviewCount ?? 0,
        lat: vendor.lat ?? null,
        lng: vendor.lng ?? null,
        pin_hash: pinHash,
        created_at: seedAt,
        updated_at: seedAt,
      });
    }

    for (const product of products) {
      insertProduct.run({
        id: product.id,
        vendor_id: product.vendorId,
        name: product.name,
        price_cents: product.priceCents,
        description: product.description || '',
        category: product.category || 'Herbal remedy',
        tags: JSON.stringify(product.tags || []),
        image_asset: product.imageAsset ?? null,
        in_stock: product.inStock === false ? 0 : 1,
        can_buy_online: product.canBuyOnline ? 1 : 0,
        created_at: seedAt,
        updated_at: seedAt,
      });
    }

    db.prepare(
      'INSERT OR REPLACE INTO meta (key, value) VALUES (?, ?)',
    ).run('catalog_seeded_at', seedAt);
  });

  tx();
  console.log(`Seeded ${vendors.length} vendors and ${products.length} products.`);
  console.log('Demo vendor PIN for all seeded vendors: 1234');
}

module.exports = { seed };

if (require.main === module) {
  seed();
}
