-- Join key: Google email (normalized). google_sub kept only as optional OIDC metadata.

-- 1) subjects: rebuild around email PK
ALTER TABLE subjects ADD COLUMN IF NOT EXISTS email_norm TEXT;

UPDATE subjects
SET email_norm = lower(trim(email))
WHERE email IS NOT NULL AND trim(email) <> '';

UPDATE subjects
SET email_norm = lower(google_sub) || '@legacy.soup.invalid'
WHERE email_norm IS NULL;

ALTER TABLE subjects ALTER COLUMN email_norm SET NOT NULL;

ALTER TABLE device_links DROP CONSTRAINT IF EXISTS device_links_google_sub_fkey;
ALTER TABLE sessions DROP CONSTRAINT IF EXISTS sessions_google_sub_fkey;

CREATE TABLE subjects_email (
  email TEXT PRIMARY KEY,
  google_sub TEXT UNIQUE,
  name TEXT,
  picture_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO subjects_email (email, google_sub, name, picture_url, created_at, updated_at)
SELECT DISTINCT ON (email_norm)
  email_norm,
  google_sub,
  name,
  picture_url,
  created_at,
  updated_at
FROM subjects
ORDER BY email_norm, updated_at DESC;

DROP TABLE subjects CASCADE;
ALTER TABLE subjects_email RENAME TO subjects;

-- 2) device_links (recreate FKs after subjects rebuild; CASCADE dropped them)
ALTER TABLE device_links ADD COLUMN IF NOT EXISTS email TEXT;
UPDATE device_links d
SET email = s.email
FROM subjects s
WHERE d.google_sub IS NOT NULL AND s.google_sub = d.google_sub;
DELETE FROM device_links WHERE email IS NULL AND google_sub IS NOT NULL;
ALTER TABLE device_links DROP COLUMN IF EXISTS google_sub;
ALTER TABLE device_links
  ADD CONSTRAINT device_links_email_fkey
  FOREIGN KEY (email) REFERENCES subjects(email);

-- 3) sessions
ALTER TABLE sessions ADD COLUMN IF NOT EXISTS email TEXT;
UPDATE sessions s
SET email = sub.email
FROM subjects sub
WHERE s.google_sub IS NOT NULL AND sub.google_sub = s.google_sub;
DELETE FROM sessions WHERE email IS NULL;
ALTER TABLE sessions ALTER COLUMN email SET NOT NULL;
ALTER TABLE sessions DROP COLUMN IF EXISTS google_sub;
ALTER TABLE sessions
  ADD CONSTRAINT sessions_email_fkey
  FOREIGN KEY (email) REFERENCES subjects(email) ON DELETE CASCADE;
DROP INDEX IF EXISTS idx_sessions_google_sub;
CREATE INDEX IF NOT EXISTS idx_sessions_email ON sessions(email);

-- 4) entitlements
ALTER TABLE entitlements ADD COLUMN IF NOT EXISTS email TEXT;
UPDATE entitlements e
SET email = s.email
FROM subjects s
WHERE e.google_sub IS NOT NULL AND s.google_sub = e.google_sub;
UPDATE entitlements
SET email = 'dev@example.com'
WHERE email IS NULL AND google_sub IN ('dev-google-sub-001', 'dev-google-sub-002', 'dev-google-sub-003');
DELETE FROM entitlements WHERE email IS NULL;
DELETE FROM entitlements a
USING entitlements b
WHERE a.ctid < b.ctid
  AND a.server_id = b.server_id
  AND a.email = b.email;
ALTER TABLE entitlements DROP CONSTRAINT IF EXISTS entitlements_pkey;
ALTER TABLE entitlements DROP COLUMN IF EXISTS google_sub;
ALTER TABLE entitlements ALTER COLUMN email SET NOT NULL;
ALTER TABLE entitlements ADD PRIMARY KEY (server_id, email);
DROP INDEX IF EXISTS idx_entitlements_google_sub;
CREATE INDEX IF NOT EXISTS idx_entitlements_email ON entitlements(email);

-- 5) transport_grants
ALTER TABLE transport_grants ADD COLUMN IF NOT EXISTS email TEXT;
UPDATE transport_grants g
SET email = s.email
FROM subjects s
WHERE g.google_sub IS NOT NULL AND s.google_sub = g.google_sub;
UPDATE transport_grants
SET email = 'dev@example.com'
WHERE email IS NULL AND google_sub IN ('dev-google-sub-001', 'dev-google-sub-002', 'dev-google-sub-003');
DELETE FROM transport_grants WHERE email IS NULL;
ALTER TABLE transport_grants DROP CONSTRAINT IF EXISTS transport_grants_server_id_google_sub_id_key;
ALTER TABLE transport_grants DROP COLUMN IF EXISTS google_sub;
ALTER TABLE transport_grants ALTER COLUMN email SET NOT NULL;
ALTER TABLE transport_grants ADD CONSTRAINT transport_grants_server_email_id_key UNIQUE (server_id, email, id);
DROP INDEX IF EXISTS idx_transport_grants_lookup;
CREATE INDEX IF NOT EXISTS idx_transport_grants_lookup
  ON transport_grants(server_id, email)
  WHERE claimed_at IS NULL AND revoked_at IS NULL;
