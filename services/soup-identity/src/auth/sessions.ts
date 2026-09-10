import type { Env } from "../env.js";
import type { Db } from "../db/client.js";
import {
  randomToken,
  randomUserCode,
  sha256,
  signAccessToken,
  type SigningKeys,
} from "../lib/crypto.js";

const DEVICE_LINK_TTL_SECONDS = 600;

export async function upsertSubject(
  db: Db,
  subject: {
    googleSub: string;
    email?: string | null;
    name?: string | null;
    pictureUrl?: string | null;
  },
) {
  await db.query(
    `INSERT INTO subjects (google_sub, email, name, picture_url)
     VALUES ($1, $2, $3, $4)
     ON CONFLICT (google_sub) DO UPDATE SET
       email = COALESCE(EXCLUDED.email, subjects.email),
       name = COALESCE(EXCLUDED.name, subjects.name),
       picture_url = COALESCE(EXCLUDED.picture_url, subjects.picture_url),
       updated_at = now()`,
    [
      subject.googleSub,
      subject.email ?? null,
      subject.name ?? null,
      subject.pictureUrl ?? null,
    ],
  );
}

export async function createSession(
  db: Db,
  keys: SigningKeys,
  env: Env,
  input: { googleSub: string; email?: string | null; deviceName?: string },
) {
  const refreshToken = randomToken(48);
  const expiresAt = new Date(
    Date.now() + env.REFRESH_TOKEN_TTL_DAYS * 24 * 60 * 60 * 1000,
  );
  await db.query(
    `INSERT INTO sessions (google_sub, refresh_token_hash, device_name, expires_at)
     VALUES ($1, $2, $3, $4)`,
    [input.googleSub, sha256(refreshToken), input.deviceName ?? null, expiresAt],
  );
  const access = await signAccessToken(keys, env, {
    sub: input.googleSub,
    email: input.email,
  });
  return {
    access_token: access.token,
    refresh_token: refreshToken,
    expires_in: access.expiresIn,
    token_type: "Bearer" as const,
    google_sub: input.googleSub,
    email: input.email ?? null,
  };
}

export async function refreshSession(
  db: Db,
  keys: SigningKeys,
  env: Env,
  refreshToken: string,
) {
  const hash = sha256(refreshToken);
  const { rows } = await db.query<{
    id: string;
    google_sub: string;
    expires_at: Date;
    revoked_at: Date | null;
    email: string | null;
  }>(
    `SELECT s.id, s.google_sub, s.expires_at, s.revoked_at, sub.email
     FROM sessions s
     JOIN subjects sub ON sub.google_sub = s.google_sub
     WHERE s.refresh_token_hash = $1`,
    [hash],
  );
  const row = rows[0];
  if (!row || row.revoked_at || row.expires_at.getTime() < Date.now()) {
    return null;
  }

  // Rotate refresh token
  const newRefresh = randomToken(48);
  const expiresAt = new Date(
    Date.now() + env.REFRESH_TOKEN_TTL_DAYS * 24 * 60 * 60 * 1000,
  );
  await db.query(
    `UPDATE sessions
     SET refresh_token_hash = $1, expires_at = $2, last_used_at = now()
     WHERE id = $3`,
    [sha256(newRefresh), expiresAt, row.id],
  );

  const access = await signAccessToken(keys, env, {
    sub: row.google_sub,
    email: row.email,
  });
  return {
    access_token: access.token,
    refresh_token: newRefresh,
    expires_in: access.expiresIn,
    token_type: "Bearer" as const,
    google_sub: row.google_sub,
    email: row.email,
  };
}

export async function revokeSession(db: Db, refreshToken: string) {
  await db.query(
    `UPDATE sessions SET revoked_at = now()
     WHERE refresh_token_hash = $1 AND revoked_at IS NULL`,
    [sha256(refreshToken)],
  );
}

export async function startDeviceLink(db: Db, env: Env) {
  const deviceCode = randomToken(32);
  const userCode = randomUserCode();
  const expiresAt = new Date(Date.now() + DEVICE_LINK_TTL_SECONDS * 1000);
  const verificationUri = `${env.PUBLIC_BASE_URL}/auth/google/start`;
  await db.query(
    `INSERT INTO device_links
      (device_code, user_code, verification_uri, interval_seconds, expires_at, status)
     VALUES ($1, $2, $3, 5, $4, 'pending')`,
    [deviceCode, userCode, verificationUri, expiresAt],
  );
  return {
    device_code: deviceCode,
    user_code: userCode,
    verification_uri: verificationUri,
    verification_uri_complete: `${verificationUri}?user_code=${encodeURIComponent(userCode)}`,
    expires_in: DEVICE_LINK_TTL_SECONDS,
    interval: 5,
  };
}

export async function pollDeviceLink(
  db: Db,
  keys: SigningKeys,
  env: Env,
  deviceCode: string,
) {
  const { rows } = await db.query<{
    status: string;
    expires_at: Date;
    google_sub: string | null;
    email: string | null;
  }>(
    `SELECT d.status, d.expires_at, d.google_sub, s.email
     FROM device_links d
     LEFT JOIN subjects s ON s.google_sub = d.google_sub
     WHERE d.device_code = $1`,
    [deviceCode],
  );
  const row = rows[0];
  if (!row) return { kind: "missing" as const };
  if (row.status === "consumed") return { kind: "missing" as const };

  if (row.expires_at.getTime() < Date.now() && row.status === "pending") {
    await db.query(
      `UPDATE device_links SET status = 'expired' WHERE device_code = $1`,
      [deviceCode],
    );
    return { kind: "expired" as const };
  }

  if (row.status === "expired") return { kind: "expired" as const };
  if (row.status === "pending") return { kind: "pending" as const };

  if (row.status === "approved" && row.google_sub) {
    const tokens = await createSession(db, keys, env, {
      googleSub: row.google_sub,
      email: row.email,
      deviceName: "device-link",
    });
    await db.query(
      `UPDATE device_links SET status = 'consumed' WHERE device_code = $1`,
      [deviceCode],
    );
    return { kind: "approved" as const, tokens };
  }

  return { kind: "pending" as const };
}

export async function approveDeviceLink(
  db: Db,
  input: {
    userCode: string;
    googleSub: string;
    email?: string | null;
    name?: string | null;
  },
) {
  await upsertSubject(db, {
    googleSub: input.googleSub,
    email: input.email,
    name: input.name,
  });

  const { rows } = await db.query<{ device_code: string; status: string; expires_at: Date }>(
    `SELECT device_code, status, expires_at FROM device_links WHERE user_code = $1`,
    [input.userCode.toUpperCase()],
  );
  const row = rows[0];
  if (!row) return { ok: false as const, reason: "not_found" };
  if (row.expires_at.getTime() < Date.now() || row.status !== "pending") {
    return { ok: false as const, reason: "invalid" };
  }

  await db.query(
    `UPDATE device_links
     SET status = 'approved', google_sub = $1
     WHERE device_code = $2`,
    [input.googleSub, row.device_code],
  );
  return { ok: true as const };
}

export function googleAuthUrl(env: Env, state: string): string {
  const params = new URLSearchParams({
    client_id: env.GOOGLE_CLIENT_ID,
    redirect_uri: env.GOOGLE_REDIRECT_URI,
    response_type: "code",
    scope: "openid email profile",
    access_type: "online",
    include_granted_scopes: "true",
    state,
    prompt: "select_account",
  });
  return `https://accounts.google.com/o/oauth2/v2/auth?${params}`;
}

export async function exchangeGoogleCode(env: Env, code: string) {
  const body = new URLSearchParams({
    code,
    client_id: env.GOOGLE_CLIENT_ID,
    client_secret: env.GOOGLE_CLIENT_SECRET,
    redirect_uri: env.GOOGLE_REDIRECT_URI,
    grant_type: "authorization_code",
  });
  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body,
  });
  if (!tokenRes.ok) {
    const text = await tokenRes.text();
    throw new Error(`Google token exchange failed: ${tokenRes.status} ${text}`);
  }
  const tokens = (await tokenRes.json()) as { access_token: string; id_token?: string };
  const userRes = await fetch("https://openidconnect.googleapis.com/v1/userinfo", {
    headers: { authorization: `Bearer ${tokens.access_token}` },
  });
  if (!userRes.ok) {
    throw new Error(`Google userinfo failed: ${userRes.status}`);
  }
  const profile = (await userRes.json()) as {
    sub: string;
    email?: string;
    name?: string;
    picture?: string;
  };
  return profile;
}

/** Opaque state for OIDC round-trip (user_code optional). */
export function encodeOAuthState(userCode?: string): string {
  return Buffer.from(
    JSON.stringify({ user_code: userCode ?? null, n: randomToken(8) }),
  ).toString("base64url");
}

export function decodeOAuthState(state: string): { user_code: string | null } {
  try {
    const parsed = JSON.parse(Buffer.from(state, "base64url").toString("utf8")) as {
      user_code?: string | null;
    };
    return { user_code: parsed.user_code ?? null };
  } catch {
    return { user_code: null };
  }
}
