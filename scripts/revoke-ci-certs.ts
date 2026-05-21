#!/usr/bin/env bun
/**
 * Revoke iOS Development certificates that THIS CI run created.
 *
 * Why this exists: every release-tagged CI run signs the .ipa via
 * `xcodebuild archive -allowProvisioningUpdates`, which mints a fresh
 * "Apple Development" cert and registers it with the App Store Connect
 * API key. Ephemeral GitHub runners never reuse the cert, but the
 * portal copy lingers. Apple caps Development certs at 2 per account,
 * so after ~2 unattended releases the next build fails with
 *   "Your account has reached the maximum number of certificates."
 * and a human has to log into developer.apple.com and revoke them
 * manually.
 *
 * Strategy: after upload, walk every Development cert on the portal
 * and revoke those whose expirationDate is more than 364 days away.
 * Apple Development certs are valid for exactly 1 year, so a freshly-
 * created cert expires ~365 days from now and a >364-day filter
 * catches anything minted in the last 24h — i.e. this run's cert
 * plus any leftovers from earlier runs that weren't cleaned up.
 * It will never touch a human-owned cert (they're months into their
 * year) or Distribution / Developer ID certs (different `certificateType`).
 *
 * Failure modes: any HTTP error logs and exits 0 — cleanup is hygiene,
 * not part of the release path; we never want to fail a successful
 * release because the cleanup step couldn't reach Apple's API.
 *
 * Env:
 *   ASC_KEY_ID, ASC_ISSUER_ID — required, same secrets the upload uses.
 *   DRY_RUN=1 — list candidates without revoking. Useful for the first
 *     run against a real account, or for verifying behaviour after
 *     changing the heuristic.
 *
 * The `Install App Store Connect API key` step in release.yml already
 * writes the P8 to ~/.appstoreconnect/private_keys/AuthKey_<id>.p8;
 * we read it from there to avoid double secret handling in this script.
 *
 * Known limitations (good to be aware of before relying on this in
 * environments beyond a single solo-maintained CI account):
 *
 * - **Concurrent release tags.** Two `v*` tags pushed within ~minute
 *   each spawn a runner that mints a cert. Each runner's cleanup step
 *   will revoke both certs, possibly nuking the other runner's cert
 *   mid-archive. Don't do that. The Apple API doesn't currently let us
 *   tag a cert with a run-id at creation time, so there's no safe
 *   per-run filter today.
 * - **Shared Apple ID.** If a human mints a cert via local Xcode within
 *   24h of a CI run, this script will revoke it. Fine for a CI-only
 *   account; surprising if a dev is also developing locally on the
 *   same team. Pair with a personal cert that's already several days
 *   old (which the heuristic protects) before relying on this.
 * - **365-day cert validity.** The 364-day floor presumes Apple keeps
 *   Development certs at 1 year. If they shorten to 180 days (as has
 *   happened for Distribution certs in the past), every cert would
 *   look "too old to be a CI cert" and the cap fills up silently.
 *   Apple's certificate API doesn't currently expose `createdDate`;
 *   if/when it does, swap the heuristic to "created within the last
 *   24h" for proper future-proofing.
 */
import { createSign } from "node:crypto";
import { readFileSync } from "node:fs";
import { homedir } from "node:os";

const KEY_ID = process.env.ASC_KEY_ID;
const ISSUER_ID = process.env.ASC_ISSUER_ID;
if (!KEY_ID || !ISSUER_ID) {
	console.error("[revoke] ASC_KEY_ID or ASC_ISSUER_ID missing — skipping.");
	process.exit(0);
}

const keyPath = `${homedir()}/.appstoreconnect/private_keys/AuthKey_${KEY_ID}.p8`;
let privateKey: string;
try {
	privateKey = readFileSync(keyPath, "utf8");
} catch (e) {
	console.error(`[revoke] cannot read ${keyPath} — skipping. (${(e as Error).message})`);
	process.exit(0);
}

function base64url(buf: Buffer | string): string {
	return Buffer.from(buf)
		.toString("base64")
		.replace(/=/g, "")
		.replace(/\+/g, "-")
		.replace(/\//g, "_");
}

function jwt(): string {
	const header = { alg: "ES256", kid: KEY_ID, typ: "JWT" };
	const now = Math.floor(Date.now() / 1000);
	const payload = { iss: ISSUER_ID, iat: now, exp: now + 1200, aud: "appstoreconnect-v1" };
	const data = `${base64url(JSON.stringify(header))}.${base64url(JSON.stringify(payload))}`;
	// `dsaEncoding: "ieee-p1363"` produces the fixed 64-byte (r||s) signature
	// JWS/ES256 expects. The default DER encoding fails verification.
	const sig = createSign("SHA256")
		.update(data)
		.sign({ key: privateKey, dsaEncoding: "ieee-p1363" });
	return `${data}.${base64url(sig)}`;
}

const token = jwt();
const auth = { Authorization: `Bearer ${token}` };
const dryRun = process.env.DRY_RUN === "1";
if (dryRun) console.log("[revoke] DRY_RUN=1 — will list candidates, no DELETEs");

interface Cert {
	id: string;
	attributes: {
		displayName?: string;
		certificateType?: string;
		expirationDate?: string;
		serialNumber?: string;
	};
}

interface CertPage {
	data: Cert[];
	links?: { next?: string };
}

// Apple's per-page max is 200; the account cap is 2. Pagination here is
// belt-and-suspenders for the rare case where DRY_RUN reveals a runaway
// (e.g. cap was raised, or we're querying a different cert type later).
async function listAllDevCerts(): Promise<Cert[]> {
	const all: Cert[] = [];
	let url: string | undefined =
		"https://api.appstoreconnect.apple.com/v1/certificates?filter[certificateType]=DEVELOPMENT&limit=200";
	while (url) {
		const resp: Response = await fetch(url, { headers: auth });
		if (!resp.ok) {
			console.error(`[revoke] LIST ${resp.status}: ${await resp.text()}`);
			return all;
		}
		const page = (await resp.json()) as CertPage;
		all.push(...page.data);
		url = page.links?.next;
	}
	return all;
}

const certs = await listAllDevCerts();
console.log(`[revoke] Found ${certs.length} DEVELOPMENT cert(s) on the portal`);

const now = Date.now();
const STALE_MS = 364 * 24 * 60 * 60 * 1000;
let revoked = 0;
let kept = 0;

for (const cert of certs) {
	const { displayName = "(no name)", expirationDate, serialNumber } = cert.attributes;
	if (!expirationDate) {
		console.log(`[revoke]   keep    ${cert.id}  ${displayName}  (no expirationDate)`);
		kept++;
		continue;
	}
	const exp = Date.parse(expirationDate);
	const remaining = exp - now;
	// A cert minted today expires in ~365 days; anything still >364 days out
	// was created within the last 24 hours and is therefore a CI cert.
	if (remaining <= STALE_MS) {
		console.log(
			`[revoke]   keep    ${cert.id}  ${displayName}  (expires ${expirationDate} — too old to be a CI cert)`,
		);
		kept++;
		continue;
	}
	if (dryRun) {
		console.log(
			`[revoke]   would   ${cert.id}  ${displayName}  (serial ${serialNumber ?? "?"})`,
		);
		revoked++;
		continue;
	}
	const del = await fetch(`https://api.appstoreconnect.apple.com/v1/certificates/${cert.id}`, {
		method: "DELETE",
		headers: auth,
	});
	if (del.ok) {
		console.log(
			`[revoke]   revoke  ${cert.id}  ${displayName}  (serial ${serialNumber ?? "?"})`,
		);
		revoked++;
	} else {
		console.log(`[revoke]   FAIL    ${cert.id}  ${del.status} ${await del.text()}`);
	}
}

console.log(`[revoke] Done: revoked=${revoked} kept=${kept}`);
