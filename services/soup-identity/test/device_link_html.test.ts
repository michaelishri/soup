import assert from "node:assert/strict";
import { test } from "node:test";
import {
  deviceLinkDevForm,
  deviceLinkEnterCode,
  deviceLinkError,
  deviceLinkSuccess,
  escapeHtml,
} from "../src/lib/device_link_html.ts";

test("escapeHtml escapes markup", () => {
  assert.equal(escapeHtml(`<"&>`), "&lt;&quot;&amp;&gt;");
});

test("dev form includes Festival chrome and escaped user code", () => {
  const html = deviceLinkDevForm({
    userCode: `AB<>"`,
    emailPlaceholder: "a@b.c",
  });
  assert.match(html, /Barlow Condensed/);
  assert.match(html, /--cobalt:\s*#2541c8/);
  assert.match(html, /brand-mark">Soup</);
  assert.match(html, /AB&lt;&gt;&quot;/);
  assert.match(html, /Approve device/);
  assert.match(html, /name="email"/);
  assert.doesNotMatch(html, /google_sub/);
});

test("enter-code form posts TV code with link token and never dumps tokens", () => {
  const html = deviceLinkEnterCode({
    identity: "dev@example.com",
    linkToken: "proof.jwt.here",
    prefillUserCode: "ABCD-EFGH",
  });
  assert.match(html, /Enter your TV code/);
  assert.match(html, /action="\/auth\/google\/link-device"/);
  assert.match(html, /name="link_token"/);
  assert.match(html, /name="user_code"/);
  assert.match(html, /ABCD-EFGH/);
  assert.match(html, /dev@example\.com/);
  assert.doesNotMatch(html, /access_token|refresh_token|pre class="tokens"/);
});

test("success and error pages share shell", () => {
  const ok = deviceLinkSuccess({
    heading: "Device linked",
    messageHtml: "Linked <strong>a@b.c</strong>.",
  });
  const err = deviceLinkError({
    heading: "Code expired",
    messageHtml: "Try again.",
  });
  assert.match(ok, /status-success/);
  assert.match(err, /status-error/);
  assert.match(ok, /Identity/);
  assert.match(err, /Identity/);
  assert.match(ok, /return to Soup on the TV/);
});
