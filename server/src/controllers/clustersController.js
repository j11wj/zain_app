const binModel = require('../models/binModel');
const { clusterBins, DEFAULT_K } = require('../services/kmeansService');
const { formatBin } = require('./binsController');

async function getClusters(req, res, next) {
  try {
    const k = req.query.k ? parseInt(req.query.k, 10) : DEFAULT_K;
    const bins = binModel.getAllBins().map(formatBin);
    const result = clusterBins(bins, k);
    res.json(result);
  } catch (e) {
    next(e);
  }
}

module.exports = { getClusters };
