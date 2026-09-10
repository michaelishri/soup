-- Soup Identity v1 schema

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE IF NOT EXISTS subjects (
  google_sub TEXT PRIMARY KEY,
  email TEXT,
  name TEXT,
  picture_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS device_links (
  device_code TEXT PRIMARY KEY,
  user_code TEXT NOT NULL UNIQUE,
  verification_uri TEXT NOT NULL,
  interval_seconds INT NOT NULL DEFAULT 5,
  expires_at TIMESTAMPTZ NOT NULL,
  google_sub TEXT REFERENCES subjects(google_sub),
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'approved', 'expired', 'consumed')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_device_links_user_code ON device_links(user_code);

CREATE TABLE IF NOT EXISTS sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  google_sub TEXT NOT NULL REFERENCES subjects(google_sub) ON DELETE CASCADE,
  refresh_token_hash TEXT NOT NULL UNIQUE,
  device_name TEXT,
  expires_at TIMESTAMPTZ NOT NULL,
  revoked_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_used_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_sessions_google_sub ON sessions(google_sub);

CREATE TABLE IF NOT EXISTS plugin_credentials (
  plugin_id TEXT PRIMARY KEY,
  secret_hash TEXT NOT NULL,
  label TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  revoked_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS servers (
  server_id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  base_url TEXT,
  magic_dns TEXT,
  audience TEXT NOT NULL,
  plugin_id TEXT NOT NULL REFERENCES plugin_credentials(plugin_id),
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS entitlements (
  server_id TEXT NOT NULL REFERENCES servers(server_id) ON DELETE CASCADE,
  google_sub TEXT NOT NULL,
  display_name TEXT,
  jellyfin_user_hint TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (server_id, google_sub)
);

CREATE INDEX IF NOT EXISTS idx_entitlements_google_sub ON entitlements(google_sub);

-- Transport grants table reserved for Wave 2 (single-claim Tailscale auth keys).
CREATE TABLE IF NOT EXISTS transport_grants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  server_id TEXT NOT NULL REFERENCES servers(server_id) ON DELETE CASCADE,
  google_sub TEXT NOT NULL,
  grant_type TEXT NOT NULL DEFAULT 'tailscale_auth_key',
  material TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  claimed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (server_id, google_sub, id)
);

CREATE INDEX IF NOT EXISTS idx_transport_grants_lookup
  ON transport_grants(server_id, google_sub)
  WHERE claimed_at IS NULL;
