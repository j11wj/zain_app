const { getPredictionsForAllBins, trainModel } = require('../services/predictionService');

async function getPredictions(req, res, next) {
  try {
    const train = trainModel();
    const predictions = getPredictionsForAllBins();
    res.json({
      model: train.trained ? 'RandomForestRegression' : 'fallback',
      training: train,
      predictions,
    });
  } catch (e) {
    next(e);
  }
}

module.exports = { getPredictions };
