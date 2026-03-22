const binModel = require('../models/binModel');

async function getMonthlyStats(req, res, next) {
  try {
    const rows = binModel.getMonthlyHistoryStats();
    res.json({ months: rows });
  } catch (e) {
    next(e);
  }
}

module.exports = { getMonthlyStats };
