const { getCollectionRoute } = require('../services/routeService');

async function getRoute(req, res, next) {
  try {
    const route = getCollectionRoute();
    res.json(route);
  } catch (e) {
    next(e);
  }
}

module.exports = { getRoute };
