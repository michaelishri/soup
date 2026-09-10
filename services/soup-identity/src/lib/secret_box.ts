import { createCipheriv, createDecipheriv, randomBytes } from "node:crypto";

const PREFIX = "v1";

/** Resolve a 32-byte AES key from hex (64) or base64/base64url. */
export function parseEncryptionKey(raw: string): Buffer {
  const trimmed = raw.trim();
  if (!trimmed) {
    throw new Error("TRANSPORT_GRANT_ENCRYPTION_KEY is empty");
  }
  if (/^[0-9a-fA-F]{64}$/.test(trimmed)) {
    return Buffer.from(trimmed, "hex");
  }
  const b64 = trimmed.replace(/-/g, "+").replace(/_/g, "/");
  const padded = b64 + "=".repeat((4 - (b64.length % 4)) % 4);
  const key = Buffer.from(padded, "base64");
  if (key.length !== 32) {
    throw new Error(
      "TRANSPORT_GRANT_ENCRYPTION_KEY must be 32 bytes (64 hex or base64)",
    );
  }
  return key;
}

/** AES-256-GCM; format `v1.<iv>.<tag>.<ciphertext>` (base64url). */
export function sealSecret(plaintext: string, key: Buffer): string {
  const iv = randomBytes(12);
  const cipher = createCipheriv("aes-256-gcm", key, iv);
  const ciphertext = Buffer.concat([
    cipher.update(plaintext, "utf8"),
    cipher.final(),
  ]);
  const tag = cipher.getAuthTag();
  return [
    PREFIX,
    iv.toString("base64url"),
    tag.toString("base64url"),
    ciphertext.toString("base64url"),
  ].join(".");
}

export function openSecret(sealed: string, key: Buffer): string {
  const parts = sealed.split(".");
  if (parts.length !== 4 || parts[0] !== PREFIX) {
    throw new Error("Unrecognized sealed secret format");
  }
  const [, ivB64, tagB64, dataB64] = parts;
  const iv = Buffer.from(ivB64!, "base64url");
  const tag = Buffer.from(tagB64!, "base64url");
  const data = Buffer.from(dataB64!, "base64url");
  const decipher = createDecipheriv("aes-256-gcm", key, iv);
  decipher.setAuthTag(tag);
  return Buffer.concat([decipher.update(data), decipher.final()]).toString(
    "utf8",
  );
}
