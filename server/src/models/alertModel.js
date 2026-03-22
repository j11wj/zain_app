const { db } = require('../config/database');

function insertAlert(type, binId, message) {
  const ts = new Date().toISOString();
  const r = db
    .prepare(
      'INSERT INTO alerts (type, bin_id, message, timestamp) VALUES (?, ?, ?, ?)'
    )
    .run(type, binId ?? null, message, ts);
  return { id: r.lastInsertRowid, type, bin_id: binId, message, timestamp: ts };
}

function getRecentAlerts(limit = 100) {
  return db
    .prepare(
      'SELECT * FROM alerts ORDER BY timestamp DESC LIMIT ?'
    )
    .all(limit);
}

module.exports = { insertAlert, getRecentAlerts };
