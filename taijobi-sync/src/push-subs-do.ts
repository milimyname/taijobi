/**
 * PushSubs — Durable Object holding all push-notification subscriptions.
 *
 * Single DO (keyed by a fixed name, e.g. "push-subs") that stores every
 * subscription in a SQLite table. The cron handler (scheduled()) queries
 * this DO for subscriptions due for a notification, iterates, signs VAPID,
 * sends pushes, and updates last_notified_at.
 *
 * Routes handled inside this DO:
 *   POST   /subscribe  — upsert subscription for a sync key
 *   DELETE /subscribe  — remove subscription
 *   POST   /heartbeat  — update last_review_at timestamp
 *   GET    /due        — return subscriptions that need a notification
 */

interface SubRow {
  sync_key_hash: string;
  endpoint: string;
  p256dh: string;
  auth: string;
  last_review_at: number;
  last_notified_at: number;
  created_at: number;
}

export class PushSubs implements DurableObject {
  private sql: SqlStorage;

  constructor(private state: DurableObjectState) {
    this.sql = state.storage.sql;
    this.sql.exec(`
      CREATE TABLE IF NOT EXISTS subs (
        sync_key_hash   TEXT PRIMARY KEY,
        endpoint        TEXT NOT NULL,
        p256dh          TEXT NOT NULL,
        auth            TEXT NOT NULL,
        last_review_at  INTEGER NOT NULL DEFAULT 0,
        last_notified_at INTEGER NOT NULL DEFAULT 0,
        created_at      INTEGER NOT NULL
      )
    `);
  }

  async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);
    const syncKeyHash = request.headers.get("X-Sync-Key-Hash") ?? "";

    if (request.method === "POST" && url.pathname === "/subscribe") {
      return this.handleSubscribe(syncKeyHash, request);
    }
    if (request.method === "DELETE" && url.pathname === "/subscribe") {
      return this.handleUnsubscribe(syncKeyHash);
    }
    if (request.method === "POST" && url.pathname === "/heartbeat") {
      return this.handleHeartbeat(syncKeyHash, request);
    }
    if (request.method === "GET" && url.pathname === "/due") {
      return this.handleDue();
    }
    if (request.method === "POST" && url.pathname === "/notified") {
      return this.handleNotified(request);
    }

    return Response.json({ error: "Not found" }, { status: 404 });
  }

  private async handleSubscribe(syncKeyHash: string, request: Request): Promise<Response> {
    const { subscription } = (await request.json()) as {
      subscription: { endpoint: string; keys: { p256dh: string; auth: string } };
    };
    if (!subscription?.endpoint || !subscription?.keys?.p256dh || !subscription?.keys?.auth) {
      return Response.json({ error: "Invalid subscription" }, { status: 400 });
    }
    this.sql.exec(
      `INSERT INTO subs (sync_key_hash, endpoint, p256dh, auth, last_review_at, last_notified_at, created_at)
       VALUES (?, ?, ?, ?, ?, 0, ?)
       ON CONFLICT(sync_key_hash) DO UPDATE SET
         endpoint = excluded.endpoint,
         p256dh   = excluded.p256dh,
         auth     = excluded.auth`,
      syncKeyHash,
      subscription.endpoint,
      subscription.keys.p256dh,
      subscription.keys.auth,
      Date.now(),
      Date.now(),
    );
    return Response.json({ ok: true });
  }

  private handleUnsubscribe(syncKeyHash: string): Response {
    this.sql.exec("DELETE FROM subs WHERE sync_key_hash = ?", syncKeyHash);
    return Response.json({ ok: true });
  }

  private async handleHeartbeat(syncKeyHash: string, request: Request): Promise<Response> {
    const { ts } = (await request.json()) as { ts: number };
    const now = typeof ts === "number" && ts > 0 ? ts : Date.now();
    this.sql.exec(
      "UPDATE subs SET last_review_at = ? WHERE sync_key_hash = ?",
      now,
      syncKeyHash,
    );
    return Response.json({ ok: true });
  }

  /**
   * Return all subs where:
   * - (now - last_review_at) is between 20h and 28h  (the reminder window)
   * - (now - last_notified_at) > 18h                 (no spam)
   */
  private handleDue(): Response {
    const now = Date.now();
    const windowStart = now - 28 * 3600_000; // 28h ago
    const windowEnd = now - 20 * 3600_000; // 20h ago
    const noSpam = now - 18 * 3600_000; // 18h ago

    const rows = this.sql.exec(
      `SELECT sync_key_hash, endpoint, p256dh, auth, last_review_at, last_notified_at, created_at
       FROM subs
       WHERE last_review_at > ? AND last_review_at < ?
         AND last_notified_at < ?`,
      windowStart,
      windowEnd,
      noSpam,
    ).toArray() as unknown as SubRow[];

    return Response.json({ subs: rows });
  }

  /** Mark a subscription as notified (called by the cron after successful push). */
  private async handleNotified(request: Request): Promise<Response> {
    const { sync_key_hash } = (await request.json()) as { sync_key_hash: string };
    this.sql.exec(
      "UPDATE subs SET last_notified_at = ? WHERE sync_key_hash = ?",
      Date.now(),
      sync_key_hash,
    );
    return Response.json({ ok: true });
  }
}
