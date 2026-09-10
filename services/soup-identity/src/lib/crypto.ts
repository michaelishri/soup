import { createHash, randomBytes, timingSafeEqual } from "node:crypto";
import { readFile, writeFile, mkdir } from "node:fs/promises";
import path from "node:path";
import {
  exportJWK,
  exportPKCS8,
  exportSPKI,
  generateKeyPair,
  importPKCS8,
  importSPKI,
  SignJWT,
  jwtVerify,
  type JWK,
} from "jose";
import type { Env } from "../env.js";

type CryptoKeyLike = Awaited<ReturnType<typeof importPKCS8>>;

export function sha256(input: string): string {
  return createHash("sha256").update(input).digest("hex");
}

export function randomToken(bytes = 32): string {
  return randomBytes(bytes).toString("base64url");
}

export function randomUserCode(): string {
  // TV-friendly: XXXX-XXXX using unambiguous charset
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  const pick = () => alphabet[randomBytes(1)[0]! % alphabet.length]!;
  return `${Array.from({ length: 4 }, pick).join("")}-${Array.from({ length: 4 }, pick).join("")}`;
}

export function safeEqual(a: string, b: string): boolean {
  const ba = Buffer.from(a);
  const bb = Buffer.from(b);
  if (ba.length !== bb.length) return false;
  return timingSafeEqual(ba, bb);
}

export type SigningKeys = {
  alg: "EdDSA" | "RS256";
  privateKey: CryptoKeyLike;
  publicKey: CryptoKeyLike;
  publicJwk: JWK;
  kid: string;
};

async function loadOrCreatePemPair(
  env: Env,
  dataDir: string,
): Promise<{ privatePem: string; publicPem: string }> {
  if (env.JWT_PRIVATE_KEY_PEM && env.JWT_PUBLIC_KEY_PEM) {
    return {
      privatePem: env.JWT_PRIVATE_KEY_PEM.replace(/\\n/g, "\n"),
      publicPem: env.JWT_PUBLIC_KEY_PEM.replace(/\\n/g, "\n"),
    };
  }

  await mkdir(dataDir, { recursive: true });
  const privPath = path.join(dataDir, `jwt-${env.JWT_ALG.toLowerCase()}.pkcs8`);
  const pubPath = path.join(dataDir, `jwt-${env.JWT_ALG.toLowerCase()}.spki`);

  try {
    const privatePem = await readFile(privPath, "utf8");
    const publicPem = await readFile(pubPath, "utf8");
    return { privatePem, publicPem };
  } catch {
    const alg = env.JWT_ALG === "RS256" ? "RS256" : "EdDSA";
    const { privateKey, publicKey } = await generateKeyPair(alg, {
      extractable: true,
      ...(alg === "RS256" ? { modulusLength: 2048 } : {}),
    });
    const privatePem = await exportPKCS8(privateKey);
    const publicPem = await exportSPKI(publicKey);
    await writeFile(privPath, privatePem, { mode: 0o600 });
    await writeFile(pubPath, publicPem, { mode: 0o644 });
    return { privatePem, publicPem };
  }
}

export async function loadSigningKeys(
  env: Env,
  dataDir = path.join(process.cwd(), "data"),
): Promise<SigningKeys> {
  const { privatePem, publicPem } = await loadOrCreatePemPair(env, dataDir);
  const alg = env.JWT_ALG;
  const privateKey = await importPKCS8(privatePem, alg);
  const publicKey = await importSPKI(publicPem, alg);
  const publicJwk = await exportJWK(publicKey);
  const kid = sha256(JSON.stringify(publicJwk)).slice(0, 16);
  publicJwk.kid = kid;
  publicJwk.alg = alg;
  publicJwk.use = "sig";
  return { alg, privateKey, publicKey, publicJwk, kid };
}

export async function signAccessToken(
  keys: SigningKeys,
  env: Env,
  claims: { sub: string; email?: string | null },
): Promise<{ token: string; expiresIn: number }> {
  const expiresIn = env.ACCESS_TOKEN_TTL_SECONDS;
  const token = await new SignJWT({
    typ: "soup_access",
    email: claims.email ?? undefined,
  })
    .setProtectedHeader({ alg: keys.alg, kid: keys.kid, typ: "JWT" })
    .setSubject(claims.sub)
    .setIssuer(env.ASSERTION_ISSUER)
    .setAudience("soup-app")
    .setIssuedAt()
    .setExpirationTime(`${expiresIn}s`)
    .sign(keys.privateKey);
  return { token, expiresIn };
}

export async function verifyAccessToken(
  keys: SigningKeys,
  env: Env,
  token: string,
): Promise<{ sub: string; email?: string }> {
  const { payload } = await jwtVerify(token, keys.publicKey, {
    issuer: env.ASSERTION_ISSUER,
    audience: "soup-app",
  });
  if (!payload.sub) throw new Error("missing sub");
  return {
    sub: payload.sub,
    email: typeof payload.email === "string" ? payload.email : undefined,
  };
}

export async function signAssertion(
  keys: SigningKeys,
  env: Env,
  input: {
    googleSub: string;
    email?: string | null;
    audience: string;
    serverId: string;
  },
): Promise<{ assertion: string; expiresIn: number }> {
  const expiresIn = env.ASSERTION_TTL_SECONDS;
  const assertion = await new SignJWT({
    typ: "soup_assertion",
    email: input.email ?? undefined,
    server_id: input.serverId,
  })
    .setProtectedHeader({ alg: keys.alg, kid: keys.kid, typ: "JWT" })
    .setSubject(input.googleSub)
    .setIssuer(env.ASSERTION_ISSUER)
    .setAudience(input.audience)
    .setIssuedAt()
    .setExpirationTime(`${expiresIn}s`)
    .sign(keys.privateKey);
  return { assertion, expiresIn };
}
