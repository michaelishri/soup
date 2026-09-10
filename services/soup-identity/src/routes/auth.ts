import { Hono } from "hono";
import type { Env } from "../env.js";
import type { Db } from "../db/client.js";
import type { SigningKeys } from "../lib/crypto.js";
import type { AppEnv } from "../middleware/auth.js";
import {
  approveDeviceLink,
  decodeOAuthState,
  encodeOAuthState,
  exchangeGoogleCode,
  googleAuthUrl,
  pollDeviceLink,
  refreshSession,
  revokeSession,
  startDeviceLink,
  upsertSubject,
  createSession,
} from "../auth/sessions.js";

export function buildAuthRoutes(deps: {
  db: Db;
  env: Env;
  keys: SigningKeys;
}) {
  const app = new Hono<AppEnv>();

  app.post("/auth/device/link", async (c) => {
    const started = await startDeviceLink(deps.db, deps.env);
    return c.json(started);
  });

  app.get("/auth/device/link/:deviceCode", async (c) => {
    const result = await pollDeviceLink(
      deps.db,
      deps.keys,
      deps.env,
      c.req.param("deviceCode"),
    );
    if (result.kind === "missing") {
      return c.json({ error: "not_found", message: "Unknown device code" }, 404);
    }
    if (result.kind === "pending") return c.json({ status: "pending" });
    if (result.kind === "expired") return c.json({ status: "expired" });
    return c.json({ status: "approved", ...result.tokens });
  });

  app.post("/auth/device/approve", async (c) => {
    const body = await c.req.json<{
      user_code: string;
      google_sub: string;
      email?: string;
      name?: string;
    }>();
    if (!body.user_code || !body.google_sub) {
      return c.json({ error: "bad_request", message: "user_code and google_sub required" }, 400);
    }
    const result = await approveDeviceLink(deps.db, {
      userCode: body.user_code,
      googleSub: body.google_sub,
      email: body.email,
      name: body.name,
    });
    if (!result.ok && result.reason === "not_found") {
      return c.json({ error: "not_found", message: "Unknown user code" }, 404);
    }
    if (!result.ok) {
      return c.json({ error: "bad_request", message: "Code invalid or expired" }, 400);
    }
    return c.json({ status: "approved" });
  });

  app.get("/auth/google/start", async (c) => {
    const userCode = c.req.query("user_code") ?? undefined;
    if (deps.env.googleConfigured) {
      const state = encodeOAuthState(userCode);
      return c.redirect(googleAuthUrl(deps.env, state), 302);
    }
    if (!deps.env.ALLOW_DEV_LOGIN) {
      return c.json(
        {
          error: "unavailable",
          message: "Google OIDC not configured and ALLOW_DEV_LOGIN is false",
        },
        503,
      );
    }
    // Dev HTML form so a phone/browser can approve without Google
    const code = userCode ?? "";
    return c.html(`<!doctype html>
<html><head><meta charset="utf-8"><title>Soup Dev Login</title>
<style>body{font-family:system-ui;max-width:28rem;margin:3rem auto;padding:0 1rem}
input,button{font-size:1rem;padding:.5rem;width:100%;margin:.35rem 0}</style></head>
<body>
<h1>Soup device link (dev)</h1>
<p>Google client env is unset. Approving with <code>DEV_GOOGLE_*</code>.</p>
<form method="POST" action="/auth/dev/complete">
  <label>User code</label>
  <input name="user_code" value="${escapeHtml(code)}" required />
  <label>Google sub (optional)</label>
  <input name="google_sub" placeholder="${escapeHtml(deps.env.DEV_GOOGLE_SUB)}" />
  <label>Email (optional)</label>
  <input name="email" placeholder="${escapeHtml(deps.env.DEV_GOOGLE_EMAIL)}" />
  <button type="submit">Approve device</button>
</form>
</body></html>`);
  });

  app.get("/auth/google/callback", async (c) => {
    const err = c.req.query("error");
    if (err) {
      return c.html(`<p>Google error: ${escapeHtml(err)}</p>`, 400);
    }
    const code = c.req.query("code");
    const state = c.req.query("state") ?? "";
    if (!code) return c.html("<p>Missing code</p>", 400);
    if (!deps.env.googleConfigured) {
      return c.html("<p>Google not configured</p>", 400);
    }
    try {
      const profile = await exchangeGoogleCode(deps.env, code);
      await upsertSubject(deps.db, {
        googleSub: profile.sub,
        email: profile.email,
        name: profile.name,
        pictureUrl: profile.picture,
      });
      const { user_code } = decodeOAuthState(state);
      if (user_code) {
        const approved = await approveDeviceLink(deps.db, {
          userCode: user_code,
          googleSub: profile.sub,
          email: profile.email,
          name: profile.name,
        });
        if (!approved.ok) {
          return c.html(
            `<p>Signed in as ${escapeHtml(profile.email ?? profile.sub)}, but device code was invalid/expired. Enter the code on the TV again.</p>`,
            400,
          );
        }
        return c.html(
          `<p>Linked <strong>${escapeHtml(profile.email ?? profile.sub)}</strong> to the Soup device. You can close this tab.</p>`,
        );
      }
      // Browser-only login without device code: issue tokens in page (dev convenience)
      const tokens = await createSession(deps.db, deps.keys, deps.env, {
        googleSub: profile.sub,
        email: profile.email,
        deviceName: "browser",
      });
      return c.html(
        `<p>Signed in as ${escapeHtml(profile.email ?? profile.sub)}.</p>
         <pre style="white-space:pre-wrap;word-break:break-all">${escapeHtml(JSON.stringify(tokens, null, 2))}</pre>`,
      );
    } catch (e) {
      const message = e instanceof Error ? e.message : "oauth_failed";
      return c.html(`<p>${escapeHtml(message)}</p>`, 400);
    }
  });

  app.post("/auth/dev/complete", async (c) => {
    if (!deps.env.ALLOW_DEV_LOGIN) {
      return c.json({ error: "forbidden", message: "Dev login disabled" }, 403);
    }
    const contentType = c.req.header("content-type") ?? "";
    let userCode: string;
    let googleSub: string | undefined;
    let email: string | undefined;
    if (contentType.includes("application/json")) {
      const body = await c.req.json<{
        user_code: string;
        google_sub?: string;
        email?: string;
      }>();
      userCode = body.user_code;
      googleSub = body.google_sub;
      email = body.email;
    } else {
      const form = await c.req.parseBody();
      userCode = String(form.user_code ?? "");
      googleSub = form.google_sub ? String(form.google_sub) : undefined;
      email = form.email ? String(form.email) : undefined;
    }
    if (!userCode) {
      return c.json({ error: "bad_request", message: "user_code required" }, 400);
    }
    const sub = googleSub || deps.env.DEV_GOOGLE_SUB;
    const mail = email || deps.env.DEV_GOOGLE_EMAIL;
    const result = await approveDeviceLink(deps.db, {
      userCode,
      googleSub: sub,
      email: mail,
      name: "Dev User",
    });
    if (!result.ok && result.reason === "not_found") {
      return c.html("<p>Unknown user code</p>", 404);
    }
    if (!result.ok) {
      return c.html("<p>Code invalid or expired</p>", 400);
    }
    if (contentType.includes("application/json")) {
      return c.json({ status: "approved", google_sub: sub, email: mail });
    }
    return c.html(
      `<p>Approved device for <code>${escapeHtml(sub)}</code>. Return to the Soup app.</p>`,
    );
  });

  app.post("/v1/sessions/refresh", async (c) => {
    const body = await c.req.json<{ refresh_token: string }>();
    if (!body.refresh_token) {
      return c.json({ error: "bad_request", message: "refresh_token required" }, 400);
    }
    const tokens = await refreshSession(
      deps.db,
      deps.keys,
      deps.env,
      body.refresh_token,
    );
    if (!tokens) {
      return c.json({ error: "unauthorized", message: "Invalid refresh token" }, 401);
    }
    return c.json(tokens);
  });

  app.post("/v1/sessions/revoke", async (c) => {
    const body = await c.req.json<{ refresh_token: string }>();
    if (!body.refresh_token) {
      return c.json({ error: "bad_request", message: "refresh_token required" }, 400);
    }
    await revokeSession(deps.db, body.refresh_token);
    return c.body(null, 204);
  });

  return app;
}

function escapeHtml(s: string): string {
  return s
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}
