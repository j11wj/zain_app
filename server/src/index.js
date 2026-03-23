/**
 * Entry point: HTTP server, WebSocket broadcast, simulation loop.
 */
require('dotenv').config({ path: require('path').join(__dirname, '../.env') });
const http = require('http');
const { WebSocketServer } = require('ws');
const app = require('./app');
const binModel = require('./models/binModel');
const simulationService = require('./services/simulationService');

binModel.migrateBinLocationsToDiwaniyahOnce();
binModel.seedBinsIfEmpty();

const port = parseInt(process.env.PORT || '3000', 10);
/** 0.0.0.0 = استقبال من أي واجهة شبكة (مناسب للسيرفر). استخدم 127.0.0.1 للتطوير المحلي فقط. */
const host =   '192.168.1.185';
const server = http.createServer(app);

const wss = new WebSocketServer({ server, path: '/ws' });

const clients = new Set();
wss.on('connection', (ws) => {
  clients.add(ws);
  ws.send(JSON.stringify({ type: 'hello', message: 'connected to smart-waste stream' }));
  ws.on('close', () => clients.delete(ws));
});

simulationService.setBroadcast((msg) => {
  const payload = JSON.stringify(msg);
  for (const ws of clients) {
    if (ws.readyState === 1) ws.send(payload);
  }
});

const autoStart = process.env.SIMULATION_AUTO_START !== 'false';
if (autoStart) {
  simulationService.start();
} else {
  console.log('Simulation auto-start disabled (SIMULATION_AUTO_START=false)');
}

server.listen(port, host, () => {
  console.log(`Smart waste API listening on http://${host}:${port}`);
  console.log(`Dashboard: http://127.0.0.1:${port}/ (or your server IP)`);
  console.log(`WebSocket: ws://${host}:${port}/ws`);
});
