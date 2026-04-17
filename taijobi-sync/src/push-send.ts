/**
 * Web Push delivery — VAPID JWT signing + AES-128-GCM payload encryption.
 *
 * Uses `crypto.subtle` only (no deps). Runs inside Cloudflare Workers.
 *
 * References:
 *   - RFC 8292 (VAPID)
 *   - RFC 8291 (Web Push payload encryption, aes128gcm)
 *   - RFC 8188 (AES-128-GCM content encoding)
 */

// --- Encoding helpers ---

function base64urlEncode(buf: ArrayBuffer | Uint8Array): string {
  const bytes = buf instanceof Uint8Array ? buf : new Uint8Array(buf);
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function base64urlDecode(str: string): Uint8Array {
  const padded = str + "=".repeat((4 - (str.length % 4)) % 4);
  const raw = atob(padded.replace(/-/g, "+").replace(/_/g, "/"));
  const out = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) out[i] = raw.charCodeAt(i);
  return out;
}

function concat(...parts: Uint8Array[]): Uint8Array {
  const total = parts.reduce((s, p) => s + p.length, 0);
  const result = new Uint8Array(total);
  let offset = 0;
  for (const p of parts) {
    result.set(p, offset);
    offset += p.length;
  }
  return result;
}

// --- VAPID JWT signing ---

export interface VapidKeys {
  publicKeyBase64: string; // base64url, 65-byte uncompressed P-256 point
  privateKeyJwk: JsonWebKey; // JWK with "d" field
}

async function signVapidJwt(audience: string, keys: VapidKeys): Promise<string> {
  const header = base64urlEncode(
    new TextEncoder().encode(JSON.stringify({ typ: "JWT", alg: "ES256" })),
  );
  const payload = base64urlEncode(
    new TextEncoder().encode(
      JSON.stringify({
        aud: audience,
        exp: Math.floor(Date.now() / 1000) + 12 * 3600, // 12h
        sub: "mailto:taijobi@mili-my.name",
      }),
    ),
  );

  const signingKey = await crypto.subtle.importKey(
    "jwk",
    keys.privateKeyJwk,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );

  const sig = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    signingKey,
    new TextEncoder().encode(`${header}.${payload}`),
  );

  return `${header}.${payload}.${base64urlEncode(sig)}`;
}

// --- Web Push payload encryption (RFC 8291, aes128gcm) ---

async function encryptPayload(
  payloadBytes: Uint8Array,
  p256dhBase64: string,
  authBase64: string,
): Promise<{ body: Uint8Array; salt: Uint8Array; localPublicKey: Uint8Array }> {
  const uaPublicKey = base64urlDecode(p256dhBase64);
  const authSecret = base64urlDecode(authBase64);

  // Generate ephemeral ECDH key pair
  const localKeyPair = (await crypto.subtle.generateKey(
    { name: "ECDH", namedCurve: "P-256" },
    true,
    ["deriveBits"],
  )) as CryptoKeyPair;

  // Import the subscriber's public key
  const subscriberKey = await crypto.subtle.importKey(
    "raw",
    uaPublicKey,
    { name: "ECDH", namedCurve: "P-256" },
    false,
    [],
  );

  // Derive shared secret via ECDH
  // Workers types use `$public` instead of `public` (TS reserved word).
  const sharedSecret = new Uint8Array(
    await crypto.subtle.deriveBits(
      { name: "ECDH", $public: subscriberKey } as SubtleCryptoDeriveKeyAlgorithm,
      localKeyPair.privateKey,
      256,
    ),
  );

  // Export local public key (raw, 65 bytes uncompressed)
  const localPublicKey = new Uint8Array(
    (await crypto.subtle.exportKey("raw", localKeyPair.publicKey)) as ArrayBuffer,
  );

  // Generate salt (16 bytes)
  const salt = crypto.getRandomValues(new Uint8Array(16));

  // HKDF to derive the IKM from shared secret + auth
  const authInfo = concat(
    new TextEncoder().encode("WebPush: info\0"),
    uaPublicKey,
    localPublicKey,
  );
  const prkKey = await crypto.subtle.importKey("raw", sharedSecret, "HKDF", false, [
    "deriveBits",
  ]);
  const ikm = new Uint8Array(
    await crypto.subtle.deriveBits(
      { name: "HKDF", hash: "SHA-256", salt: authSecret, info: authInfo },
      prkKey,
      256,
    ),
  );

  // Derive CEK and nonce from IKM + salt
  const ikmKey = await crypto.subtle.importKey("raw", ikm, "HKDF", false, ["deriveBits"]);
  const cekInfo = new TextEncoder().encode("Content-Encoding: aes128gcm\0");
  const nonceInfo = new TextEncoder().encode("Content-Encoding: nonce\0");

  const cek = new Uint8Array(
    await crypto.subtle.deriveBits(
      { name: "HKDF", hash: "SHA-256", salt, info: cekInfo },
      ikmKey,
      128,
    ),
  );
  const nonce = new Uint8Array(
    await crypto.subtle.deriveBits(
      { name: "HKDF", hash: "SHA-256", salt, info: nonceInfo },
      ikmKey,
      96,
    ),
  );

  // Pad the payload (add a delimiter byte + zero padding if desired)
  const padded = concat(payloadBytes, new Uint8Array([2])); // delimiter = 2 (final record)

  // AES-128-GCM encrypt
  const aesKey = await crypto.subtle.importKey("raw", cek, "AES-GCM", false, ["encrypt"]);
  const encrypted = new Uint8Array(
    await crypto.subtle.encrypt({ name: "AES-GCM", iv: nonce }, aesKey, padded),
  );

  // Build the aes128gcm header: salt (16) + rs (4, big-endian) + idlen (1) + keyid (65)
  const rs = new Uint8Array(4);
  new DataView(rs.buffer).setUint32(0, 4096, false); // record size
  const header = concat(salt, rs, new Uint8Array([65]), localPublicKey);

  return { body: concat(header, encrypted), salt, localPublicKey };
}

// --- Public API ---

export interface PushSubscription {
  endpoint: string;
  p256dh: string;
  auth: string;
}

export async function sendPush(
  sub: PushSubscription,
  payload: object,
  vapidKeys: VapidKeys,
): Promise<{ ok: boolean; status: number }> {
  const payloadBytes = new TextEncoder().encode(JSON.stringify(payload));

  // VAPID JWT — audience is the origin of the push endpoint
  const audience = new URL(sub.endpoint).origin;
  const jwt = await signVapidJwt(audience, vapidKeys);

  // Encrypt the payload per RFC 8291
  const { body } = await encryptPayload(payloadBytes, sub.p256dh, sub.auth);

  const res = await fetch(sub.endpoint, {
    method: "POST",
    headers: {
      Authorization: `vapid t=${jwt}, k=${vapidKeys.publicKeyBase64}`,
      "Content-Encoding": "aes128gcm",
      "Content-Type": "application/octet-stream",
      TTL: "86400", // 24h
    },
    body,
  });

  return { ok: res.ok, status: res.status };
}
