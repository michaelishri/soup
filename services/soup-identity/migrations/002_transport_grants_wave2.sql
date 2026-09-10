-- Wave 2: single-claim transport grants (Tailscale auth-key mailbox)

ALTER TABLE transport_grants
  ADD COLUMN IF NOT EXISTS tailscale_key_id TEXT,
  ADD COLUMN IF NOT EXISTS capabilities JSONB NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS revoked_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS single_claim BOOLEAN NOT NULL DEFAULT true;

CREATE INDEX IF NOT EXISTS idx_transport_grants_claimable
  ON transport_grants(server_id, google_sub, expires_at)
  WHERE claimed_at IS NULL AND revoked_at IS NULL;
