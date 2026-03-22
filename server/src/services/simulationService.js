/**
 * Simulation engine: periodic bin telemetry updates.
 * States: running + not paused → ticks apply; paused → ticks no-op (data frozen for inspection);
 * stopped → no interval until start().
 */
const binModel = require('../models/binModel');
const { evaluateBinsAndAlert } = require('./alertEvaluationService');
const { trainModel } = require('./predictionService');

let intervalId = null;
let paused = false;
let running = false;

/** @type {null|((msg: object) => void)} */
let broadcast = null;

function setBroadcast(fn) {
  broadcast = fn;
}

function getIntervalMs() {
  return parseInt(process.env.SIMULATION_INTERVAL_MS || '5000', 10);
}

function emitState(extra = {}) {
  if (broadcast) {
    broadcast({
      type: 'simulation',
      running,
      paused,
      intervalMs: getIntervalMs(),
      ...extra,
    });
  }
}

function getStatus() {
  return {
    running,
    paused,
    intervalMs: getIntervalMs(),
  };
}

function randomDelta() {
  return (Math.random() - 0.45) * 8;
}

function tick() {
  if (!running || paused) {
    return;
  }

  const bins = binModel.getAllBins();
  for (const b of bins) {
    let fill = Math.min(100, Math.max(0, b.fill_level + randomDelta()));
    let gas = Math.min(100, Math.max(0, b.gas_level + (Math.random() - 0.4) * 6));

    let fire = b.fire_status;
    if (Math.random() < 0.0008) fire = 1;
    if (Math.random() < 0.02 && fire) fire = 0;

    binModel.updateBin(b.id, {
      fill_level: fill,
      gas_level: gas,
      fire_status: fire,
    });
    binModel.insertHistory(b.id, fill);
  }

  evaluateBinsAndAlert();
  trainModel();

  if (broadcast) {
    broadcast({ type: 'tick', at: new Date().toISOString() });
  }
}

/**
 * Start the simulation loop (first tick runs immediately).
 */
function start() {
  if (intervalId) {
    running = true;
    paused = false;
    emitState({ action: 'start' });
    return getStatus();
  }
  running = true;
  paused = false;
  const ms = getIntervalMs();
  tick();
  intervalId = setInterval(tick, ms);
  emitState({ action: 'start' });
  return getStatus();
}

/**
 * Stop: no more ticks until start().
 */
function stop() {
  if (intervalId) clearInterval(intervalId);
  intervalId = null;
  running = false;
  paused = false;
  emitState({ action: 'stop' });
  return getStatus();
}

/**
 * Pause: interval keeps firing but tick does not mutate DB (freeze values).
 */
function pause() {
  if (!running) {
    return getStatus();
  }
  paused = true;
  emitState({ action: 'pause' });
  return getStatus();
}

/**
 * Resume from pause.
 */
function resume() {
  if (!running) {
    return getStatus();
  }
  paused = false;
  emitState({ action: 'resume' });
  return getStatus();
}

module.exports = {
  start,
  stop,
  pause,
  resume,
  tick,
  setBroadcast,
  getStatus,
  getIntervalMs,
};
