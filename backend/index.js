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

app.post('/api/assets', async (req, res) => {
  const { name, assetType, owner, location, status } = req.body;

  if (!name || !assetType || !owner) {
    return res.status(400).json({ error: 'name, assetType, and owner are required' });
  }

  try {
    const result = await pool.query(
      `INSERT INTO assets (name, asset_type, owner, location, status)
       VALUES ($1, $2, $3, $4, COALESCE($5, 'Active'))
       RETURNING *`,
      [name, assetType, owner, location || null, status || null]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to create asset' });
  }
});

app.patch('/api/vulnerabilities/:id', async (req, res) => {
  const { id } = req.params;
  const { status } = req.body;

  const allowedStatuses = ['Open', 'Fixed'];
  if (!status || !allowedStatuses.includes(status)) {
    return res.status(400).json({ error: `status must be one of: ${allowedStatuses.join(', ')}` });
  }

  try {
    const result = await pool.query(
      `UPDATE vulnerabilities
       SET status = $1, updated_at = now()
       WHERE id = $2
       RETURNING *`,
      [status, id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Vulnerability not found' });
    }

    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to update vulnerability' });
  }
});

const PORT = process.env.PORT || 5000;
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Sentinel backend listening on port ${PORT}`);
});