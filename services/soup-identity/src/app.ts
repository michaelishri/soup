import { Hono } from "hono";
import { cors } from "hono/cors";
import type { Env } from "./env.js";
import type { Db } from "./db/client.js";
import type { SigningKeys } from "./lib/crypto.js";
import { buildAuthRoutes } from "./routes/auth.js";
import { buildMeRoutes } from "./routes/me.js";
import { buildPluginRoutes } from "./routes/plugin.js";
import type { AppEnv } from "./middleware/auth.js";
import { redactSecrets } from "./lib/redact.js";

export function createApp(deps: {
  db: Db;
  env: Env;
  keys: SigningKeys;
}): Hono<AppEnv> {
  const app = new Hono<AppEnv>();
  app.use("*", cors());

  app.get("/healthz", (c) => c.json({ ok: true }));
  app.get("/.well-known/jwks.json", (c) =>
    c.json({ keys: [deps.keys.publicJwk] }),
  );

  app.route("/", buildAuthRoutes(deps));
  app.route("/", buildMeRoutes(deps));
  app.route("/", buildPluginRoutes(deps));

  app.notFound((c) =>
    c.json(
      { error: "not_found", message: `No route ${c.req.method} ${c.req.path}` },
      404,
    ),
  );
  app.onError((err, c) => {
    const message =
      err instanceof Error ? err.message : typeof err === "string" ? err : "error";
    console.error(redactSecrets(message));
    return c.json({ error: "internal", message: "Internal server error" }, 500);
  });

  return app;
}
