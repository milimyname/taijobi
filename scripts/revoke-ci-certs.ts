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
 * Env: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_CONTENT (raw P8 contents).
 * The `Install App Store Connect API key` step in release.yml already
 * writes the P8 to ~/.appstoreconnect/private_keys/AuthKey_<id>.p8;
 * we read it from there to avoid touching the secret in this script.
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

interface Cert {
	id: string;
	attributes: {
		displayName?: string;
		certificateType?: string;
		expirationDate?: string;
		serialNumber?: string;
	};
}

const listResp = await fetch(
	"https://api.appstoreconnect.apple.com/v1/certificates?filter[certificateType]=DEVELOPMENT&limit=200",
	{ headers: auth },
);
if (!listResp.ok) {
	console.error(`[revoke] LIST ${listResp.status}: ${await listResp.text()}`);
	process.exit(0);
}
const { data: certs = [] } = (await listResp.json()) as { data: Cert[] };
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
