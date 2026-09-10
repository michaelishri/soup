/** Festival-styled HTML for Soup device-link browser pages. */

export function escapeHtml(s: string): string {
  return s
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

type PageKind = "form" | "success" | "error" | "info";

type PageOptions = {
  title: string;
  eyebrow?: string;
  heading: string;
  bodyHtml: string;
  kind?: PageKind;
  status?: number;
};

const CSS = /* css */ `
:root {
  --paper: #f5f3eb;
  --surface: #fffef8;
  --cobalt: #2541c8;
  --signal: #e8f35b;
  --ink: #1c2027;
  --muted: #515867;
  --line: #aeb2b9;
  --danger: #b42318;
  --ok: #1b6b3a;
}
* { box-sizing: border-box; }
html, body { height: 100%; }
body {
  margin: 0;
  min-height: 100%;
  font-family: "IBM Plex Sans", "Segoe UI", system-ui, sans-serif;
  font-size: 1.05rem;
  line-height: 1.45;
  color: var(--ink);
  background:
    radial-gradient(120% 80% at 100% -10%, color-mix(in srgb, var(--signal) 35%, transparent), transparent 55%),
    radial-gradient(90% 60% at -10% 110%, color-mix(in srgb, var(--cobalt) 18%, transparent), transparent 50%),
    var(--paper);
}
.shell {
  min-height: 100%;
  display: grid;
  place-items: center;
  padding: 1.5rem 1rem 2.5rem;
}
.card {
  width: min(26rem, 100%);
  background: var(--surface);
  border: 2px solid var(--ink);
  box-shadow: 6px 6px 0 var(--cobalt);
  overflow: clip;
}
.brand {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  padding: 0.85rem 1.1rem;
  background: var(--cobalt);
  color: var(--signal);
}
.brand-mark {
  font-family: "Barlow Condensed", "Arial Narrow", sans-serif;
  font-weight: 800;
  font-size: 1.55rem;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  margin: 0;
}
.brand-tag {
  font-size: 0.72rem;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  opacity: 0.92;
}
.content { padding: 1.35rem 1.2rem 1.5rem; }
.eyebrow {
  margin: 0 0 0.35rem;
  font-size: 0.75rem;
  font-weight: 600;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: var(--muted);
}
h1 {
  margin: 0 0 0.75rem;
  font-family: "Barlow Condensed", "Arial Narrow", sans-serif;
  font-weight: 800;
  font-size: clamp(1.85rem, 6vw, 2.35rem);
  line-height: 0.95;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.lead { margin: 0 0 1.15rem; color: var(--muted); }
.user-code {
  display: block;
  margin: 0 0 1.25rem;
  padding: 0.85rem 0.9rem;
  font-family: "Barlow Condensed", "Arial Narrow", sans-serif;
  font-size: 2rem;
  font-weight: 800;
  letter-spacing: 0.18em;
  text-align: center;
  text-transform: uppercase;
  color: var(--cobalt);
  background: color-mix(in srgb, var(--signal) 55%, white);
  border: 2px dashed color-mix(in srgb, var(--cobalt) 55%, var(--ink));
}
form { display: grid; gap: 0.85rem; }
label {
  display: grid;
  gap: 0.35rem;
  font-size: 0.82rem;
  font-weight: 600;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: var(--muted);
}
input {
  width: 100%;
  padding: 0.7rem 0.75rem;
  font: inherit;
  color: var(--ink);
  background: var(--paper);
  border: 2px solid var(--ink);
  border-radius: 0;
}
input:focus {
  outline: 3px solid var(--signal);
  outline-offset: 2px;
}
button, .btn {
  appearance: none;
  display: inline-flex;
  justify-content: center;
  align-items: center;
  width: 100%;
  margin-top: 0.35rem;
  padding: 0.85rem 1rem;
  font-family: "Barlow Condensed", "Arial Narrow", sans-serif;
  font-size: 1.25rem;
  font-weight: 800;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  text-decoration: none;
  color: var(--ink);
  background: var(--signal);
  border: 2px solid var(--ink);
  box-shadow: 4px 4px 0 var(--ink);
  cursor: pointer;
}
button:hover, .btn:hover { transform: translate(-1px, -1px); box-shadow: 5px 5px 0 var(--ink); }
button:active, .btn:active { transform: translate(2px, 2px); box-shadow: 2px 2px 0 var(--ink); }
button:focus-visible, .btn:focus-visible, input:focus-visible {
  outline: 3px solid var(--cobalt);
  outline-offset: 2px;
}
.note {
  margin: 1rem 0 0;
  font-size: 0.88rem;
  color: var(--muted);
}
.note code, .mono {
  font-family: "IBM Plex Mono", ui-monospace, monospace;
  font-size: 0.9em;
}
.status {
  display: inline-block;
  margin: 0 0 0.85rem;
  padding: 0.2rem 0.55rem;
  font-size: 0.72rem;
  font-weight: 700;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  border: 2px solid currentColor;
}
.status-success { color: var(--ok); background: color-mix(in srgb, var(--ok) 12%, white); }
.status-error { color: var(--danger); background: color-mix(in srgb, var(--danger) 10%, white); }
.status-info { color: var(--cobalt); background: color-mix(in srgb, var(--cobalt) 10%, white); }
pre.tokens {
  margin: 1rem 0 0;
  max-height: 14rem;
  overflow: auto;
  padding: 0.75rem;
  font-family: "IBM Plex Mono", ui-monospace, monospace;
  font-size: 0.75rem;
  line-height: 1.4;
  background: var(--paper);
  border: 2px solid var(--ink);
  white-space: pre-wrap;
  word-break: break-all;
}
@media (prefers-reduced-motion: reduce) {
  button, .btn { transition: none; }
  button:hover, .btn:hover, button:active, .btn:active {
    transform: none;
    box-shadow: 4px 4px 0 var(--ink);
  }
}
`;

export function deviceLinkPage(options: PageOptions): string {
  const kind = options.kind ?? "info";
  const statusLabel =
    kind === "success" ? "Linked" : kind === "error" ? "Needs attention" : kind === "form" ? "Device link" : "Soup identity";
  const statusClass =
    kind === "success" ? "status-success" : kind === "error" ? "status-error" : "status-info";
  const eyebrow = options.eyebrow
    ? `<p class="eyebrow">${escapeHtml(options.eyebrow)}</p>`
    : "";

  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <meta name="color-scheme" content="light" />
  <title>${escapeHtml(options.title)}</title>
  <link rel="preconnect" href="https://fonts.googleapis.com" />
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
  <link href="https://fonts.googleapis.com/css2?family=Barlow+Condensed:wght@700;800&family=IBM+Plex+Mono:wght@400;500&family=IBM+Plex+Sans:wght@400;600&display=swap" rel="stylesheet" />
  <style>${CSS}</style>
</head>
<body>
  <main class="shell">
    <section class="card" aria-labelledby="page-heading">
      <header class="brand">
        <p class="brand-mark">Soup</p>
        <span class="brand-tag">Identity</span>
      </header>
      <div class="content">
        <span class="status ${statusClass}">${escapeHtml(statusLabel)}</span>
        ${eyebrow}
        <h1 id="page-heading">${escapeHtml(options.heading)}</h1>
        ${options.bodyHtml}
      </div>
    </section>
  </main>
</body>
</html>`;
}

export function deviceLinkDevForm(opts: {
  userCode: string;
  emailPlaceholder: string;
}): string {
  const codeBlock = opts.userCode
    ? `<span class="user-code" aria-label="User code">${escapeHtml(opts.userCode)}</span>`
    : "";
  return deviceLinkPage({
    title: "Soup · Link device",
    kind: "form",
    eyebrow: "Dev sign-in",
    heading: "Link this TV",
    bodyHtml: `
${codeBlock}
<form method="POST" action="/auth/dev/complete">
  <label>User code
    <input name="user_code" value="${escapeHtml(opts.userCode)}" autocomplete="one-time-code" required />
  </label>
  <label>Google email
    <input name="email" type="email" placeholder="${escapeHtml(opts.emailPlaceholder)}" />
  </label>
  <button type="submit">Approve device</button>
</form>
<p class="note">Leave email blank to use <code>DEV_GOOGLE_EMAIL</code> (${escapeHtml(opts.emailPlaceholder)}).</p>`,
  });
}

export function deviceLinkSuccess(opts: {
  heading: string;
  messageHtml: string;
  eyebrow?: string;
}): string {
  return deviceLinkPage({
    title: "Soup · Linked",
    kind: "success",
    eyebrow: opts.eyebrow ?? "You’re done",
    heading: opts.heading,
    bodyHtml: `<p class="lead">${opts.messageHtml}</p>
<p class="note">You can close this tab and return to Soup on the TV.</p>`,
  });
}

export function deviceLinkError(opts: {
  heading: string;
  messageHtml: string;
  eyebrow?: string;
}): string {
  return deviceLinkPage({
    title: "Soup · Device link",
    kind: "error",
    eyebrow: opts.eyebrow ?? "Couldn’t finish",
    heading: opts.heading,
    bodyHtml: `<p class="lead">${opts.messageHtml}</p>
<p class="note">Start again from the Soup app if the code expired.</p>`,
  });
}

/** After Google SSO: collect the TV user code (no token dump). */
export function deviceLinkEnterCode(opts: {
  identity: string;
  linkToken: string;
  prefillUserCode?: string;
  noteHtml?: string;
}): string {
  const prefill = opts.prefillUserCode ?? "";
  const note =
    opts.noteHtml ??
    "Type the code shown on your TV (or scan the QR again with a fresh code).";
  return deviceLinkPage({
    title: "Soup · Enter TV code",
    kind: "form",
    eyebrow: "Almost there",
    heading: "Enter your TV code",
    bodyHtml: `
<p class="lead">Signed in as <strong>${escapeHtml(opts.identity)}</strong>. Finish linking with the code on your TV.</p>
<form method="POST" action="/auth/google/link-device">
  <input type="hidden" name="link_token" value="${escapeHtml(opts.linkToken)}" />
  <label>TV code
    <input name="user_code" value="${escapeHtml(prefill)}" autocomplete="one-time-code" autocapitalize="characters" spellcheck="false" required placeholder="ABCD-EFGH" />
  </label>
  <button type="submit">Link TV</button>
</form>
<p class="note">${note}</p>`,
  });
}
