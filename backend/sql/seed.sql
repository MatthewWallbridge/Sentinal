-- 20 assets with varied type/owner/location/status
INSERT INTO assets (name, asset_type, owner, location, status)
SELECT
  'Asset-' || i,
  (ARRAY['Server','Laptop','Network Device','Workstation','Mobile Device'])[1 + (i % 5)],
  (ARRAY['IT','Matthew','Infrastructure','Finance','Sales'])[1 + (i % 5)],
  (ARRAY['Owheo Building','Data Center','Remote','Head Office'])[1 + (i % 4)],
  (ARRAY['Active','Active','Active','Retired'])[1 + (i % 4)]
FROM generate_series(1, 20) AS i;

-- 40 vulnerabilities, 2 per asset
INSERT INTO vulnerabilities (asset_id, title, description, severity, status, date_found)
SELECT
  a.id,
  (ARRAY['Outdated Apache','Missing Security Updates','Weak Password Policy','Unpatched OpenSSL','Open RDP Port','Default Credentials'])[1 + (s % 6)],
  'Auto-generated demo vulnerability for seeding purposes.',
  (ARRAY['Critical','High','Medium','Low'])[1 + (s % 4)],
  (ARRAY['Open','Open','Fixed'])[1 + (s % 3)],
  now() - (s || ' days')::interval
FROM assets a
CROSS JOIN generate_series(1, 2) AS s;

-- Investigation notes on roughly a third of vulnerabilities
INSERT INTO notes (vulnerability_id, text)
SELECT v.id, 'Investigation note: reviewed on ' || (now() - (v.id || ' hours')::interval)::date || '. Assigned for remediation.'
FROM vulnerabilities v
WHERE v.id % 3 = 0;