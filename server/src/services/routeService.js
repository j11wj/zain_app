/**
 * Builds optimal collection route for bins at or above fill threshold using A*.
 */
const binModel = require('../models/binModel');
const { getDepot } = require('./depotService');
const { computeOptimalCollectionRoute } = require('./astarService');
const { FILL_ALERT } = require('./alertEvaluationService');

function getCollectionRoute() {
  const threshold = FILL_ALERT();
  const bins = binModel.getAllBins();
  const depot = getDepot();
  const needPickup = bins.filter((b) => b.fill_level >= threshold);
  const result = computeOptimalCollectionRoute(depot, needPickup);
  return {
    depot,
    fill_threshold: threshold,
    target_bin_count: needPickup.length,
    ...result,
  };
}

module.exports = { getCollectionRoute };
