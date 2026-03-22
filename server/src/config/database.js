/**
 * SQLite connection and schema bootstrap (clean architecture: infrastructure layer).
 */
const Database = require('better-sqlite3');
const path = require('path');
const fs = require('fs');

const dbPath = process.env.SQLITE_PATH || path.join(__dirname, '../../data/waste.db');
fs.mkdirSync(path.dirname(dbPath), { recursive: true });

const db = new Database(dbPath);

db.pragma('journal_mode = WAL');

function migrate() {
  db.exec(`
    CREATE TABLE IF NOT EXISTS bins (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      lat REAL NOT NULL,
      lng REAL NOT NULL,
      fill_level REAL NOT NULL DEFAULT 0,
      gas_level REAL NOT NULL DEFAULT 0,
      fire_status INTEGER NOT NULL DEFAULT 0
    );

    CREATE TABLE IF NOT EXISTS history (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      bin_id INTEGER NOT NULL,
      fill_level REAL NOT NULL,
      timestamp TEXT NOT NULL,
      FOREIGN KEY (bin_id) REFERENCES bins(id)
    );

    CREATE TABLE IF NOT EXISTS alerts (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      type TEXT NOT NULL,
      bin_id INTEGER,
      message TEXT NOT NULL,
      timestamp TEXT NOT NULL,
      FOREIGN KEY (bin_id) REFERENCES bins(id)
    );

    CREATE INDEX IF NOT EXISTS idx_history_bin_time ON history(bin_id, timestamp);
    CREATE INDEX IF NOT EXISTS idx_alerts_time ON alerts(timestamp);
  `);
}

migrate();

module.exports = { db, dbPath };
