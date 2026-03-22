/**
 * Random Forest regression to predict next fill level from recent history.
 * Features: last 3 recorded fill levels (lag features).
 */
const { RandomForestRegression } = require('ml-random-forest');
const binModel = require('../models/binModel');

function buildDataset() {
  const bins = binModel.getAllBins();
  const X = [];
  const y = [];

  for (const bin of bins) {
    const rows = binModel
      .getHistoryForBin(bin.id, 400)
      .sort((a, b) => new Date(a.timestamp) - new Date(b.timestamp));

    for (let i = 3; i < rows.length; i++) {
      X.push([
        rows[i - 3].fill_level,
        rows[i - 2].fill_level,
        rows[i - 1].fill_level,
      ]);
      y.push(rows[i].fill_level);
    }
  }

  return { X, y };
}

let cachedModel = null;
let lastTrainSize = 0;

function trainModel() {
  const { X, y } = buildDataset();
  if (X.length < 8) {
    cachedModel = null;
    lastTrainSize = X.length;
    return { trained: false, samples: X.length, reason: 'not_enough_history' };
  }

  const rf = new RandomForestRegression({
    nEstimators: 40,
    maxFeatures: 0.9,
    seed: 42,
    useSampleBagging: true,
  });
  rf.train(X, y);
  cachedModel = rf;
  lastTrainSize = X.length;
  return { trained: true, samples: X.length };
}

function predictNextFillForBin(binId) {
  const rows = binModel
    .getHistoryForBin(binId, 20)
    .sort((a, b) => new Date(a.timestamp) - new Date(b.timestamp));

  if (rows.length < 3) {
    const bin = binModel.getBinById(binId);
    return {
      bin_id: binId,
      predicted_fill_level: bin ? Math.round(bin.fill_level * 10) / 10 : 0,
      method: 'current_snapshot',
    };
  }

  const last3 = rows.slice(-3).map((r) => r.fill_level);
  if (!cachedModel) {
    const trend = (last3[2] - last3[0]) / 2;
    const pred = Math.min(100, Math.max(0, last3[2] + trend));
    return {
      bin_id: binId,
      predicted_fill_level: Math.round(pred * 10) / 10,
      method: 'linear_extrapolation',
    };
  }

  const pred = cachedModel.predict([last3])[0];
  const clamped = Math.min(100, Math.max(0, pred));
  return {
    bin_id: binId,
    predicted_fill_level: Math.round(clamped * 10) / 10,
    method: 'random_forest',
  };
}

function getPredictionsForAllBins() {
  if (!cachedModel || lastTrainSize < 8) trainModel();
  const bins = binModel.getAllBins();
  return bins.map((b) => predictNextFillForBin(b.id));
}

module.exports = {
  trainModel,
  predictNextFillForBin,
  getPredictionsForAllBins,
  buildDataset,
};
