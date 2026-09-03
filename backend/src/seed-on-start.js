const { seed } = require('./seed');

function seedIfEmpty() {
  const db = require('./db');
  const vendorCount = db.prepare('SELECT COUNT(*) AS c FROM vendors').get().c;
  if (vendorCount === 0) {
    seed();
  }
}

module.exports = { seedIfEmpty };
