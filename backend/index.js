require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');

const app = express();
app.use(cors());
app.use(express.json());

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

app.get('/api/health', (req, res) => {
  res.json({ status: 'ok' });
});

app.get('/api/dashboard', async (req, res) => {
  try {
    const assets = await pool.query('SELECT count(*) FROM assets');
    const bySeverity = await pool.query(
      'SELECT severity, count(*) FROM vulnerabilities GROUP BY severity ORDER BY severity'
    );
    const byStatus = await pool.query(
      'SELECT status, count(*) FROM vulnerabilities GROUP BY status ORDER BY status'
    );
    res.json({
      totalAssets: Number(assets.rows[0].count),
      vulnerabilitiesBySeverity: bySeverity.rows,
      vulnerabilitiesByStatus: byStatus.rows,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to load dashboard data' });
  }
});

app.get('/api/assets', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM assets ORDER BY id');
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to load assets' });
  }
});


app.get('/api/vulnerabilities', async (req, res) => {
    try {
        const result = await pool.query(
            'SELECT * FROM vulnerabilities ORDER BY id'
        );

        res.json(result.rows);
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Failed to load vulnerabilities' });
    }
});


const PORT = process.env.PORT || 5000;
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Sentinel backend listening on port ${PORT}`);
});