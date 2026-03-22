/**
 * Creates alerts when thresholds are crossed (called after simulation tick).
 */
const binModel = require('../models/binModel');
const alertModel = require('../models/alertModel');

const FILL_ALERT = () => parseFloat(process.env.FILL_ALERT_THRESHOLD || '80', 10);
const GAS_HIGH = () => parseFloat(process.env.GAS_HIGH_THRESHOLD || '70', 10);

/** @type Map<string, number> last alert key -> timestamp ms */
const recentKeys = new Map();
const DEDUP_MS = 60000;

function shouldEmit(key) {
  const now = Date.now();
  const last = recentKeys.get(key);
  if (last && now - last < DEDUP_MS) return false;
  recentKeys.set(key, now);
  return true;
}

function evaluateBinsAndAlert() {
  const bins = binModel.getAllBins();
  const created = [];

  for (const b of bins) {
    if (b.fill_level > FILL_ALERT()) {
      const key = `fill:${b.id}`;
      if (shouldEmit(key)) {
        created.push(
          alertModel.insertAlert(
            'high_fill',
            b.id,
            `Bin ${b.id} fill level ${b.fill_level.toFixed(1)}% (>${FILL_ALERT()}%)`
          )
        );
      }
    }

    if (b.gas_level > GAS_HIGH()) {
      const key = `gas:${b.id}`;
      if (shouldEmit(key)) {
        created.push(
          alertModel.insertAlert(
            'high_gas',
            b.id,
            `Bin ${b.id} gas level ${b.gas_level.toFixed(1)} (threshold ${GAS_HIGH()})`
          )
        );
      }
    }

    if (b.fire_status) {
      const key = `fire:${b.id}`;
      if (shouldEmit(key)) {
        created.push(
          alertModel.insertAlert(
            'fire',
            b.id,
            `FIRE detected at bin ${b.id} — dispatch immediately`
          )
        );
      }
    }
  }

  return created;
}

module.exports = { evaluateBinsAndAlert, FILL_ALERT, GAS_HIGH };
