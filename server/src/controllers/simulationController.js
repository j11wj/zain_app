const simulationService = require('../services/simulationService');

async function getSimulation(req, res, next) {
  try {
    res.json(simulationService.getStatus());
  } catch (e) {
    next(e);
  }
}

/**
 * Body: { "action": "start" | "stop" | "pause" | "resume" }
 */
async function postSimulation(req, res, next) {
  try {
    const action = req.body?.action;
    let status;
    switch (action) {
      case 'start':
        status = simulationService.start();
        break;
      case 'stop':
        status = simulationService.stop();
        break;
      case 'pause':
        status = simulationService.pause();
        break;
      case 'resume':
        status = simulationService.resume();
        break;
      default:
        return res.status(400).json({
          error: 'Invalid action. Use: start, stop, pause, resume',
        });
    }
    res.json({ ok: true, ...status });
  } catch (e) {
    next(e);
  }
}

module.exports = { getSimulation, postSimulation };
