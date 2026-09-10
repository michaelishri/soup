/** Patterns that must never appear in logs or operator-facing error text. */
const SECRET_PATTERNS: RegExp[] = [
  /\btskey-(?:auth|api|client)-[A-Za-z0-9_-]+/gi,
  /\bBearer\s+[A-Za-z0-9._~+/=-]+/gi,
  /\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/g,
  /"(?:access_token|refresh_token|material|client_secret|plugin_secret)"\s*:\s*"[^"]*"/gi,
  /"(?:access_token|refresh_token|material|client_secret|plugin_secret)"\s*:\s*'[^']*'/gi,
];

/** Replace auth keys, bearer tokens, JWTs, and known secret JSON fields. */
export function redactSecrets(value: string): string {
  let out = value;
  for (const pattern of SECRET_PATTERNS) {
    out = out.replace(pattern, "[redacted]");
  }
  return out;
}
