const jwt = require('jsonwebtoken');

const JWT_SECRET = process.env.JWT_SECRET || 'usizo-dev-secret-change-me';

function signVendorToken(vendorId) {
  return jwt.sign({ vendorId, role: 'vendor' }, JWT_SECRET, { expiresIn: '30d' });
}

function requireVendor(req, res, next) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) {
    return res.status(401).json({ error: 'Authentication required.' });
  }
  try {
    const payload = jwt.verify(token, JWT_SECRET);
    if (payload.role !== 'vendor' || !payload.vendorId) {
      return res.status(401).json({ error: 'Invalid vendor token.' });
    }
    req.vendorId = payload.vendorId;
    next();
  } catch (_) {
    return res.status(401).json({ error: 'Invalid or expired token.' });
  }
}

function normalizePhone(phone) {
  return String(phone || '').replace(/[^0-9+]/g, '');
}

function rowToVendor(row) {
  return {
    id: row.id,
    name: row.name,
    location: row.location,
    description: row.description,
    phone: row.phone,
    whatsapp: row.whatsapp,
    rating: row.rating,
    reviewCount: row.review_count,
    lat: row.lat,
    lng: row.lng,
  };
}

function rowToProduct(row) {
  return {
    id: row.id,
    vendorId: row.vendor_id,
    name: row.name,
    priceCents: row.price_cents,
    description: row.description,
    category: row.category,
    tags: JSON.parse(row.tags || '[]'),
    imageAsset: row.image_asset,
    inStock: row.in_stock === 1,
    canBuyOnline: row.can_buy_online === 1,
    updatedAt: row.updated_at,
  };
}

module.exports = {
  JWT_SECRET,
  signVendorToken,
  requireVendor,
  normalizePhone,
  rowToVendor,
  rowToProduct,
};
