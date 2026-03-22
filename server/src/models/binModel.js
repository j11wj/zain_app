/**
 * Data access for bins and history (repository-style).
 */
const { db } = require('../config/database');

const BIN_COUNT = 15;

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

/**
 * Seed 15 bins around a center point if table is empty.
 */
function seedBinsIfEmpty() {
  const count = db.prepare('SELECT COUNT(*) AS c FROM bins').get().c;
  if (count > 0) return;

  const centerLat = 40.758;
  const centerLng = -73.9855;
  const insert = db.prepare(
    `INSERT INTO bins (lat, lng, fill_level, gas_level, fire_status) VALUES (?, ?, ?, ?, ?)`
  );

  const rng = (i) => {
    const angle = (i / BIN_COUNT) * Math.PI * 2;
    const r = 0.008 + (i % 5) * 0.0012;
    return {
      lat: centerLat + Math.cos(angle) * r + (i % 3) * 0.0004,
      lng: centerLng + Math.sin(angle) * r + (i % 4) * 0.0003,
      fill: 20 + (i * 7) % 55,
      gas: 15 + (i * 11) % 40,
      fire: 0,
    };
  };

  const transaction = db.transaction(() => {
    for (let i = 0; i < BIN_COUNT; i++) {
      const p = rng(i);
      insert.run(p.lat, p.lng, p.fill, p.gas, p.fire);
    }
  });
  transaction();

  const bins = getAllBins();
  for (const b of bins) {
    insertHistory(b.id, b.fill_level);
  }
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
  seedBinsIfEmpty,
};
