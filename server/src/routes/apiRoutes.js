const express = require('express');
const { getBins } = require('../controllers/binsController');
const { getRoute } = require('../controllers/routeController');
const { getClusters } = require('../controllers/clustersController');
const { getPredictions } = require('../controllers/predictionsController');
const { getAlerts } = require('../controllers/alertsController');
const { getMonthlyStats } = require('../controllers/statsController');
const {
  getSimulation,
  postSimulation,
} = require('../controllers/simulationController');

const router = express.Router();

router.get('/bins', getBins);
router.get('/route', getRoute);
router.get('/clusters', getClusters);
router.get('/predictions', getPredictions);
router.get('/alerts', getAlerts);
router.get('/stats/monthly', getMonthlyStats);
router.get('/simulation', getSimulation);
router.post('/simulation', postSimulation);

module.exports = router;
