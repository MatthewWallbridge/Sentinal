import { useEffect, useState } from 'react';
import './App.css';

const API_BASE = 'http://localhost:5000/api';

function App() {
  const [dashboard, setDashboard] = useState(null);
  const [assets, setAssets] = useState([]);
  const [vulnerabilities, setVulnerabilities] = useState([]);
  const [error, setError] = useState(null);

  function loadDashboard() {
    fetch(`${API_BASE}/dashboard`)
      .then((res) => res.json())
      .then(setDashboard)
      .catch((err) => setError(err.message));
  }

  function loadAssets() {
    fetch(`${API_BASE}/assets`)
      .then((res) => res.json())
      .then(setAssets)
      .catch((err) => setError(err.message));
  }

  function loadVulnerabilities() {
    fetch(`${API_BASE}/vulnerabilities`)
      .then((res) => res.json())
      .then(setVulnerabilities)
      .catch((err) => setError(err.message));
  }

  useEffect(() => {
    loadDashboard();
    loadAssets();
    loadVulnerabilities();
  }, []);

  function toggleStatus(vuln) {
    const newStatus = vuln.status === 'Open' ? 'Fixed' : 'Open';
    fetch(`${API_BASE}/vulnerabilities/${vuln.id}`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ status: newStatus }),
    })
      .then((res) => res.json())
      .then(() => {
        loadVulnerabilities();
        loadDashboard();
      })
      .catch((err) => setError(err.message));
  }

  if (error) return <p>Failed to load data: {error}</p>;
  if (!dashboard) return <p>Loading...</p>;

  return (
    <div style={{ fontFamily: 'sans-serif', padding: '2rem' }}>
      <h1>Sentinel Dashboard</h1>
      <p>Total assets: {dashboard.totalAssets}</p>

      <h2>Vulnerabilities by severity</h2>
      <ul>
        {dashboard.vulnerabilitiesBySeverity.map((row) => (
          <li key={row.severity}>{row.severity}: {row.count}</li>
        ))}
      </ul>

      <h2>Vulnerabilities by status</h2>
      <ul>
        {dashboard.vulnerabilitiesByStatus.map((row) => (
          <li key={row.status}>{row.status}: {row.count}</li>
        ))}
      </ul>

      <h2>Assets</h2>
      <table border="1" cellPadding="6">
        <thead>
          <tr>
            <th>Name</th>
            <th>Type</th>
            <th>Owner</th>
            <th>Location</th>
            <th>Status</th>
          </tr>
        </thead>
        <tbody>
          {assets.map((asset) => (
            <tr key={asset.id}>
              <td>{asset.name}</td>
              <td>{asset.asset_type}</td>
              <td>{asset.owner}</td>
              <td>{asset.location}</td>
              <td>{asset.status}</td>
            </tr>
          ))}
        </tbody>
      </table>

      <h2>Vulnerabilities</h2>
      <table border="1" cellPadding="6">
        <thead>
          <tr>
            <th>Asset ID</th>
            <th>Title</th>
            <th>Severity</th>
            <th>Status</th>
            <th>Action</th>
          </tr>
        </thead>
        <tbody>
          {vulnerabilities.map((vuln) => (
            <tr key={vuln.id}>
              <td>{vuln.asset_id}</td>
              <td>{vuln.title}</td>
              <td>{vuln.severity}</td>
              <td>{vuln.status}</td>
              <td>
                <button onClick={() => toggleStatus(vuln)}>
                  Mark as {vuln.status === 'Open' ? 'Fixed' : 'Open'}
                </button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

export default App;