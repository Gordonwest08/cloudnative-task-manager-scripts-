// app/backend/src/index.js
require('dotenv').config();

const express = require('express');
const cors    = require('cors');
const { initDB } = require('./db');
const tasksRouter = require('./routes/tasks');

const app  = express();
const PORT = process.env.PORT || 5000;

// -------------------------------------------------------------------
// MIDDLEWARE
// -------------------------------------------------------------------
app.use(cors({
  origin: process.env.CORS_ORIGIN || '*'
}));
app.use(express.json());

// -------------------------------------------------------------------
// HEALTH ENDPOINTS
// Critical for Kubernetes — readiness and liveness probes hit these
// -------------------------------------------------------------------

// Liveness probe — is the process alive?
app.get('/health', (req, res) => {
  res.status(200).json({
    status:    'ok',
    timestamp: new Date().toISOString()
  });
});

// Readiness probe — is the app ready to serve traffic?
// Checks the database connection before returning healthy
app.get('/ready', async (req, res) => {
  try {
    const { pool } = require('./db');
    await pool.query('SELECT 1');
    res.status(200).json({
      status:   'ready',
      database: 'connected'
    });
  } catch (err) {
    res.status(503).json({
      status:   'not ready',
      database: 'disconnected',
      error:    err.message
    });
  }
});

// -------------------------------------------------------------------
// ROUTES
// -------------------------------------------------------------------
app.use('/api/tasks', tasksRouter);

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: `Route ${req.method} ${req.path} not found` });
});

// -------------------------------------------------------------------
// START
// -------------------------------------------------------------------
const start = async () => {
  await initDB();
  app.listen(PORT, () => {
    console.log(`Backend running on port ${PORT}`);
    console.log(`Health : http://localhost:${PORT}/health`);
    console.log(`Ready  : http://localhost:${PORT}/ready`);
    console.log(`Tasks  : http://localhost:${PORT}/api/tasks`);
  });
};

start();

// Health check endpoint - enhanced
app.get('/version', (req, res) => {
  res.json({
    version: '1.0.0',
    environment: process.env.NODE_ENV || 'production',
    timestamp: new Date().toISOString()
  });
});
