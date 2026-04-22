// app/backend/src/db/index.js
const { Pool } = require('pg');

// Connection pool — reuses connections instead of creating
// a new one for every request. Essential for production.
const pool = new Pool({
  host:     process.env.POSTGRES_HOST,
  port:     parseInt(process.env.POSTGRES_PORT) || 5432,
  database: process.env.POSTGRES_DB,
  user:     process.env.POSTGRES_USER,
  password: process.env.POSTGRES_PASSWORD,
});

// Create the tasks table if it doesn't exist yet.
// Runs once when the backend starts up.
const initDB = async () => {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS tasks (
        id          SERIAL PRIMARY KEY,
        title       VARCHAR(255) NOT NULL,
        completed   BOOLEAN DEFAULT FALSE,
        created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);
    console.log('Database initialised — tasks table ready');
  } catch (err) {
    console.error('Database initialisation failed:', err.message);
    process.exit(1);
  }
};

module.exports = { pool, initDB };
