/**
 * Express application (HTTP + static dashboard).
 */
const express = require('express');
const path = require('path');
const cors = require('cors');
const apiRoutes = require('./routes/apiRoutes');

const app = express();

const corsOrigin = process.env.CORS_ORIGIN || '*';
app.use(
  cors({
    origin: corsOrigin === '*' ? true : corsOrigin.split(',').map((s) => s.trim()),
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Accept', 'Authorization'],
  })
);
app.use(express.json());

app.use('/api', apiRoutes);
/** Same REST paths without /api prefix (spec + mobile clients). */
app.use(apiRoutes);

app.get('/health', (req, res) => {
  res.json({ ok: true, service: 'smart-waste-api' });
});

app.use(express.static(path.join(__dirname, '../public')));

app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).json({ error: err.message || 'Internal error' });
});

module.exports = app;
