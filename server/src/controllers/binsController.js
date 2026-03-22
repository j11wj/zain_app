const binModel = require('../models/binModel');

function formatBin(row) {
  return {
    id: row.id,
    lat: row.lat,
    lng: row.lng,
    fill_level: Math.round(row.fill_level * 10) / 10,
    gas_level: Math.round(row.gas_level * 10) / 10,
    fire_status: Boolean(row.fire_status),
  };
}

async function getBins(req, res, next) {
  try {
    const bins = binModel.getAllBins().map(formatBin);
    res.json({ count: bins.length, bins });
  } catch (e) {
    next(e);
  }
}

module.exports = { getBins, formatBin };
