/**
 * Data access for bins and history (repository-style).
 */
const { db } = require('../config/database');
const {
  DIWANIYAH_CENTER_LAT,
  DIWANIYAH_CENTER_LNG,
} = require('../config/geoDefaults');

const BIN_COUNT = 15;

/** ترحيل لمرة واحدة: إزالة مواقع العرض القديمة (مثلاً نيويورك) واستبدالها بمواقع داخل محافظة الديوانية */
const META_KEY_DIWANIYAH_BINS = 'diwaniyah_bins_v1';

function getAllBins() {
  return db.prepare('SELECT * FROM bins ORDER BY id').all();
}

function getBinById(id) {
  return db.prepare('SELECT * FROM bins WHERE id = ?').get(id);
}

function updateBin(id, { fill_level, gas_level, fire_status }) {
  db.prepare(
    `UPDATE bins SET fill_level = ?, gas_level = ?, fire_status = ? WHERE id = ?`
  ).run(fill_level, gas_level, fire_status, id);
}

function insertHistory(binId, fillLevel) {
  const ts = new Date().toISOString();
  db.prepare(
    'INSERT INTO history (bin_id, fill_level, timestamp) VALUES (?, ?, ?)'
  ).run(binId, fillLevel, ts);
}

function getHistoryForBin(binId, limit = 500) {
  return db
    .prepare(
      'SELECT bin_id, fill_level, timestamp FROM history WHERE bin_id = ? ORDER BY timestamp DESC LIMIT ?'
    )
    .all(binId, limit);
}

function getMonthlyHistoryStats() {
  return db
    .prepare(
      `SELECT strftime('%Y-%m', timestamp) AS month,
              AVG(fill_level) AS avg_fill,
              COUNT(*) AS samples
       FROM history
       GROUP BY month
       ORDER BY month`
    )
    .all();
}

function getAllHistoryAggregated(limitPerBin = 200) {
  const bins = getAllBins();
  const rows = [];
  for (const b of bins) {
    const h = db
      .prepare(
        'SELECT bin_id, fill_level, timestamp FROM history WHERE bin_id = ? ORDER BY timestamp ASC LIMIT ?'
      )
      .all(b.id, limitPerBin);
    rows.push(...h);
  }
  return rows;
}

function _rngBinRow(i, centerLat, centerLng) {
  const angle = (i / BIN_COUNT) * Math.PI * 2;
  const r = 0.008 + (i % 5) * 0.0012;
  return {
    lat: centerLat + Math.cos(angle) * r + (i % 3) * 0.0004,
    lng: centerLng + Math.sin(angle) * r + (i % 4) * 0.0003,
    fill: 20 + (i * 7) % 55,
    gas: 15 + (i * 11) % 40,
    fire: 0,
  };
}

/**
 * إدراج BIN_COUNT حاوية حول مركز الديوانية (بدون مسح الجداول).
 */
function insertDiwaniyahBins() {
  const insert = db.prepare(
    `INSERT INTO bins (lat, lng, fill_level, gas_level, fire_status) VALUES (?, ?, ?, ?, ?)`
  );

  const transaction = db.transaction(() => {
    for (let i = 0; i < BIN_COUNT; i++) {
      const p = _rngBinRow(i, DIWANIYAH_CENTER_LAT, DIWANIYAH_CENTER_LNG);
      insert.run(p.lat, p.lng, p.fill, p.gas, p.fire);
    }
  });
  transaction();

  const bins = getAllBins();
  for (const b of bins) {
    insertHistory(b.id, b.fill_level);
  }
}

/**
 * مرة واحدة بعد الترقية: حذف سجلّات الحاويات القديمة وإعادة الزرع داخل محافظة الديوانية.
 */
function migrateBinLocationsToDiwaniyahOnce() {
  const row = db
    .prepare('SELECT value FROM app_meta WHERE key = ?')
    .get(META_KEY_DIWANIYAH_BINS);
  if (row) return;

  const txn = db.transaction(() => {
    db.prepare('DELETE FROM history').run();
    db.prepare('DELETE FROM alerts').run();
    db.prepare('DELETE FROM bins').run();
  });
  txn();

  insertDiwaniyahBins();
  db.prepare('INSERT INTO app_meta (key, value) VALUES (?, ?)').run(
    META_KEY_DIWANIYAH_BINS,
    '1'
  );
}

/**
 * إذا بقيت الجداول فارغة (حالة نادرة)، زرع حاويات الديوانية.
 */
function seedBinsIfEmpty() {
  const count = db.prepare('SELECT COUNT(*) AS c FROM bins').get().c;
  if (count > 0) return;
  insertDiwaniyahBins();
}

module.exports = {
  BIN_COUNT,
  getAllBins,
  getBinById,
  updateBin,
  insertHistory,
  getHistoryForBin,
  getAllHistoryAggregated,
  getMonthlyHistoryStats,
  migrateBinLocationsToDiwaniyahOnce,
  seedBinsIfEmpty,
};
