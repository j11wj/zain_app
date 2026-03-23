/**
 * Depot coordinates for routing (start of collection path).
 */
const binModel = require('../models/binModel');
const {
  DIWANIYAH_CENTER_LAT,
  DIWANIYAH_CENTER_LNG,
} = require('../config/geoDefaults');

function getDepot() {
  const lat = process.env.DEPOT_LAT ? parseFloat(process.env.DEPOT_LAT, 10) : null;
  const lng = process.env.DEPOT_LNG ? parseFloat(process.env.DEPOT_LNG, 10) : null;
  if (lat != null && lng != null && !Number.isNaN(lat) && !Number.isNaN(lng)) {
    return { lat, lng };
  }
  const bins = binModel.getAllBins();
  if (!bins.length) {
    return { lat: DIWANIYAH_CENTER_LAT, lng: DIWANIYAH_CENTER_LNG };
  }
  const sumLat = bins.reduce((s, b) => s + b.lat, 0);
  const sumLng = bins.reduce((s, b) => s + b.lng, 0);
  return { lat: sumLat / bins.length, lng: sumLng / bins.length };
}

module.exports = { getDepot };
