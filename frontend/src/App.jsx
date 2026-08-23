import { useEffect, useState } from 'react';
import './App.css';

const API_BASE = 'http://localhost:5000/api';

function severityBadgeClass(severity) {
  return `badge badge-${severity.toLowerCase()}`;
}

function statusBadgeClass(status) {
  return `badge badge-${status.toLowerCase()}`;
}

function App() {
  const [dashboard, setDashboard] = useState(null);
  const [assets, setAssets] = useState([]);
  const [vulnerabilities, setVulnerabilities] = useState([]);
  const [error, setError] = useState(null);
  const [statusFilter, setStatusFilter] = useState('All');
  const [newAsset, setNewAsset] = useState({
    name: '',
    assetType: '',
    owner: '',
    location: '',
    status: 'Active',
  });

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

  function handleAssetChange(e) {
    setNewAsset({ ...newAsset, [e.target.name]: e.target.value });
  }

  function submitAsset(e) {
    e.preventDefault();
    fetch(`${API_BASE}/assets`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(newAsset),
    })
      .then((res) => res.json())
      .then(() => {
        setNewAsset({ name: '', assetType: '', owner: '', location: '', status: 'Active' });
        loadAssets();
        loadDashboard();
      })
      .catch((err) => setError(err.message));
  }

  function deleteAsset(asset) {
    const confirmed = window.confirm(
      `Delete "${asset.name}"? This will also delete any vulnerabilities recorded against it.`
    );
    if (!confirmed) return;

    fetch(`${API_BASE}/assets/${asset.id}`, { method: 'DELETE' })
      .then((res) => res.json())
      .then(() => {
        loadAssets();
        loadVulnerabilities();
        loadDashboard();
      })
      .catch((err) => setError(err.message));
  }

  if (error) return <p>Failed to load data: {error}</p>;
  if (!dashboard) return <p>Loading...</p>;

  const filteredAssets = assets.filter(
    (asset) => statusFilter === 'All' || asset.status === statusFilter
  );

  return (
    <div className="app">
      <h1>Sentinel Dashboard</h1>
      <p className="subtitle">Cyber asset & vulnerability tracker</p>

      <section className="card">
        <h2>Overview</h2>
        <p>Total assets: <strong>{dashboard.totalAssets}</strong></p>
        <div className="stat-group">
          <div>
            <h3>By severity</h3>
            {dashboard.vulnerabilitiesBySeverity.map((row) => (
              <span key={row.severity} className={severityBadgeClass(row.severity)}>
                {row.severity}: {row.count}
              </span>
            ))}
          </div>
          <div>
            <h3>By status</h3>
            {dashboard.vulnerabilitiesByStatus.map((row) => (
              <span key={row.status} className={statusBadgeClass(row.status)}>
                {row.status}: {row.count}
              </span>
            ))}
          </div>
        </div>
      </section>

      <section className="card">
        <h2>Add Asset</h2>
        <form onSubmit={submitAsset} className="asset-form">
          <input name="name" placeholder="Name" value={newAsset.name} onChange={handleAssetChange} required />
          <input name="assetType" placeholder="Type" value={newAsset.assetType} onChange={handleAssetChange} required />
          <input name="owner" placeholder="Owner" value={newAsset.owner} onChange={handleAssetChange} required />
          <input name="location" placeholder="Location" value={newAsset.location} onChange={handleAssetChange} />
          <select name="status" value={newAsset.status} onChange={handleAssetChange}>
            <option value="Active">Active</option>
            <option value="Retired">Retired</option>
          </select>
          <button type="submit">Add Asset</button>
        </form>
      </section>

      <section className="card">
        <div className="section-header">
          <h2>Assets</h2>
          <label>
            Filter by status:{' '}
            <select value={statusFilter} onChange={(e) => setStatusFilter(e.target.value)}>
              <option value="All">All</option>
              <option value="Active">Active</option>
              <option value="Retired">Retired</option>
            </select>
          </label>
        </div>
        <table>
          <thead>
            <tr>
              <th>Name</th>
              <th>Type</th>
              <th>Owner</th>
              <th>Location</th>
              <th>Status</th>
              <th>Action</th>
            </tr>
          </thead>
          <tbody>
            {filteredAssets.map((asset) => (
              <tr key={asset.id}>
                <td>{asset.name}</td>
                <td>{asset.asset_type}</td>
                <td>{asset.owner}</td>
                <td>{asset.location}</td>
                <td><span className={statusBadgeClass(asset.status)}>{asset.status}</span></td>
                <td>
                  <button className="delete-btn" onClick={() => deleteAsset(asset)}>
                    Delete
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {filteredAssets.length === 0 && <p>No assets match this filter.</p>}
      </section>

      <section className="card">
        <h2>Vulnerabilities</h2>
        <table>
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
                <td><span className={severityBadgeClass(vuln.severity)}>{vuln.severity}</span></td>
                <td><span className={statusBadgeClass(vuln.status)}>{vuln.status}</span></td>
                <td>
                  <button onClick={() => toggleStatus(vuln)}>
                    Mark as {vuln.status === 'Open' ? 'Fixed' : 'Open'}
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>
    </div>
  );
}

export default App;