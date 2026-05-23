#!/usr/bin/env node
// fetch-apple-siwa-domain.mjs
//
// Drives Apple's developer portal in a real Chromium window, lets you
// sign in interactively (handles 2FA), then captures every network
// response from `developer.apple.com` while you click around. The
// verification token Apple expects at
// /.well-known/apple-developer-domain-association.txt lives in one of
// those JSON responses — this script will spot it and dump it to disk.
//
// Run with:
//   cd tap
//   npm install --no-save playwright
//   npx playwright install chromium
//   node scripts/fetch-apple-siwa-domain.mjs
//
// Outputs:
//   /tmp/apple-domain-association.txt — the verification body Apple
//                                       wants served at /.well-known/...
//   /tmp/apple-portal-network.log     — full request/response trace
//                                       (post if it doesn't auto-detect)

import { chromium } from "playwright";
import { mkdir, writeFile, appendFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import { dirname } from "node:path";

const SERVICE_ID = "com.mattssoftware.fishbones.signin";
const OUT_FILE = "/tmp/apple-domain-association.txt";
const LOG_FILE = "/tmp/apple-portal-network.log";
const STATE_DIR = `${process.env.HOME}/.cache/playwright-apple-portal`;

// Heuristics for spotting the verification token. Apple's file is
// short — historically 8–64 hex chars, sometimes a JSON-ish blob with
// fields like "developmentTeam"/"associatedApplicationIdentifier". We
// try a few shapes.
function looksLikeAppleDomainAssociation(body) {
  if (!body || typeof body !== "string") return false;
  const trimmed = body.trim();
  if (!trimmed) return false;
  // Single-line hex/UUID token.
  if (/^[A-F0-9-]{8,80}$/i.test(trimmed) && trimmed.length >= 8) return true;
  // JSON shaped like the merchantid file (Apple uses similar shape
  // for SIWA — a small object with a teamId / serviceId pair).
  if (
    trimmed.startsWith("{") &&
    /(serviceID|service_id|appID|developmentTeam|teamId|domain)/i.test(trimmed)
  ) {
    return true;
  }
  return false;
}

async function main() {
  if (!existsSync(STATE_DIR)) await mkdir(STATE_DIR, { recursive: true });
  await writeFile(LOG_FILE, ""); // truncate

  console.log("── launching Chromium with persistent state at", STATE_DIR);
  const ctx = await chromium.launchPersistentContext(STATE_DIR, {
    headless: false,
    viewport: { width: 1280, height: 900 },
  });
  const page = ctx.pages()[0] || (await ctx.newPage());

  let captured = null;
  let lastUrl = "";

  // Capture every response from developer.apple.com. Some come back
  // as JSON, some as plain text — try both.
  page.on("response", async (resp) => {
    const url = resp.url();
    if (!/developer\.apple\.com|apple-cloudkit|apple\.com\/services-account/i.test(url)) return;

    const ct = resp.headers()["content-type"] || "";
    let body = "";
    try {
      body = await resp.text();
    } catch {
      return;
    }

    await appendFile(
      LOG_FILE,
      `\n── ${resp.status()} ${url}\n   content-type: ${ct}\n   ${body.slice(0, 4000)}\n`
    );

    // Direct hit: the file itself.
    if (
      /apple-developer-domain-association/i.test(url) ||
      ct.includes("application/octet-stream") ||
      looksLikeAppleDomainAssociation(body)
    ) {
      console.log(`\n── candidate body from ${url} (${resp.status()}, ${ct})`);
      console.log(body.slice(0, 800));
      if (!captured && looksLikeAppleDomainAssociation(body)) {
        captured = body;
        await writeFile(OUT_FILE, body);
        console.log(`\n✓ wrote ${OUT_FILE} (${body.length} bytes)`);
        console.log("  if this looks wrong, check", LOG_FILE, "for other candidates.");
      }
    }

    // Look for JSON responses that embed the token as a field.
    if (ct.includes("json") && body.length < 200_000) {
      try {
        const j = JSON.parse(body);
        const flat = JSON.stringify(j);
        const m = flat.match(
          /"(domainAssociationFile|domain_association_file|associationFile|webAuthAssociation|verificationToken|domainVerificationToken)"\s*:\s*"([^"]+)"/i
        );
        if (m) {
          console.log(`\n── token embedded in JSON (${m[1]}) from ${url}`);
          console.log("   ", m[2].slice(0, 200));
          if (!captured) {
            // Apple sometimes ships base64'd JSON inside JSON — try to
            // detect that and unwrap.
            let payload = m[2];
            try {
              const decoded = Buffer.from(payload, "base64").toString("utf-8");
              if (looksLikeAppleDomainAssociation(decoded)) payload = decoded;
            } catch { /* not base64 */ }
            captured = payload;
            await writeFile(OUT_FILE, payload);
            console.log(`✓ wrote ${OUT_FILE} (${payload.length} bytes)`);
          }
        }
      } catch { /* not JSON */ }
    }
  });

  page.on("framenavigated", (frame) => {
    if (frame === page.mainFrame() && frame.url() !== lastUrl) {
      lastUrl = frame.url();
      console.log("→", lastUrl);
    }
  });

  console.log(
    [
      "",
      "── Manual steps (the script watches network traffic the whole time):",
      "   1. Sign in to your Apple Developer account if prompted.",
      `   2. Navigate to your '${SERVICE_ID}' Service ID.`,
      "   3. Click 'Configure' next to 'Sign In with Apple'.",
      "   4. Click the small icon next to relay.mattssoftware.com",
      "      (the broken-looking copy/download glyph). Even though",
      "      it doesn't download, the click fires a network request",
      "      we can intercept.",
      "   5. If still nothing, try 'Save' on the outer page — saving",
      "      sometimes triggers a fresh fetch of the verification",
      "      token from Apple's API.",
      "",
      "   Network trace is being written to:",
      "     ", LOG_FILE,
      "",
      "   The script will tell you when it captures the token.",
      "   When you're done (or stuck), close the browser window and",
      "   I'll grep the log for anything useful.",
      "",
    ].join("\n")
  );

  // Start where the user is most likely to need to be.
  await page.goto(
    "https://developer.apple.com/account/resources/identifiers/list/serviceId",
    { waitUntil: "domcontentloaded" }
  ).catch(() => { /* user may need to log in first; goto can fail */ });

  // Wait until the user closes the window.
  await new Promise((resolve) => ctx.on("close", resolve));

  if (captured) {
    console.log("\n── done. Verification body in", OUT_FILE);
    console.log("    Upload with:");
    console.log(`    scp ${OUT_FILE} root@149.28.120.197:/etc/fishbones/apple-domain-association.txt`);
  } else {
    console.log(
      "\n── didn't auto-detect a token. Full network trace at",
      LOG_FILE,
      "— paste it back to me and I'll grep for the right shape."
    );
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
