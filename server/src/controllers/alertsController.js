const alertModel = require('../models/alertModel');

async function getAlerts(req, res, next) {
  try {
    const limit = req.query.limit ? parseInt(req.query.limit, 10) : 100;
    const alerts = alertModel.getRecentAlerts(limit);
    res.json({ count: alerts.length, alerts });
  } catch (e) {
    next(e);
  }
}

module.exports = { getAlerts };
