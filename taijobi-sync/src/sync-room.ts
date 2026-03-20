/**
 * SyncRoom — Durable Object with SQLite storage.
 *
 * One DO instance per sync key. Holds all WebSocket connections for that key.
 * When device A pushes changes, the DO merges into SQLite (LWW) and broadcasts
 * to all other connected devices via WebSocket.
 *
 * Uses DO's built-in SQLite — no R2 bucket needed.
 */

interface Row {
  table: string;
  id: string;
  data: Record<string, unknown> | string;
  updated_at: number;
}

interface SyncData {
  rows: Row[];
}

interface WSMessage {
  type: string;
  rows?: Row[];
  since?: number;
}

const PING_INTERVAL_MS = 30_000;

export class SyncRoom implements DurableObject {
  private initialized = false;

  constructor(
    private state: DurableObjectState,
    _env: unknown,
  ) {}

  private ensureTable(): void {
    if (this.initialized) return;
    this.state.storage.sql.exec(
      `CREATE TABLE IF NOT EXISTS sync_rows (
        tbl TEXT NOT NULL,
        row_id TEXT NOT NULL,
        data TEXT NOT NULL,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY (tbl, row_id)
      )`
    );
    this.initialized = true;
  }

  async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname.endsWith("/ws")) {
      const pair = new WebSocketPair();
      const [client, server] = [pair[0], pair[1]];
      this.state.acceptWebSocket(server);
      this.schedulePing();
      return new Response(null, { status: 101, webSocket: client });
    }

    if (request.method === "POST") {
      return this.handlePush(request);
    }

    if (request.method === "GET") {
      return this.handlePull(url);
    }

    return new Response("Method not allowed", { status: 405 });
  }

  async webSocketMessage(ws: WebSocket, message: string | ArrayBuffer): Promise<void> {
    if (typeof message !== "string") return;

    try {
      const msg = JSON.parse(message) as WSMessage;

      if (msg.type === "pong") return;

      if (msg.type === "push" && msg.rows?.length) {
        const merged = this.mergeRows(msg.rows);
        this.broadcast({ type: "changes", rows: msg.rows }, ws);
        ws.send(JSON.stringify({ type: "push_ack", merged }));
        return;
      }

      if (msg.type === "pull") {
        const since = msg.since ?? 0;
        const rows = this.getRowsSince(since);
        ws.send(JSON.stringify({ type: "pull_result", rows }));
        return;
      }
    } catch {
      // Ignore malformed messages
    }
  }

  async webSocketClose(): Promise<void> {}
  async webSocketError(): Promise<void> {}

  async alarm(): Promise<void> {
    const sockets = this.state.getWebSockets();
    if (sockets.length === 0) return;

    const ping = JSON.stringify({ type: "ping" });
    for (const ws of sockets) {
      try {
        ws.send(ping);
      } catch {
        // Dead socket
      }
    }
    this.schedulePing();
  }

  private schedulePing(): void {
    this.state.storage.setAlarm(Date.now() + PING_INTERVAL_MS);
  }

  private async handlePush(request: Request): Promise<Response> {
    const incoming = (await request.json()) as SyncData;
    if (!incoming.rows?.length) {
      return Response.json({ error: "No rows provided" }, { status: 400 });
    }
    const merged = this.mergeRows(incoming.rows);
    this.broadcast({ type: "changes", rows: incoming.rows });
    return Response.json({ merged });
  }

  private handlePull(url: URL): Response {
    const since = Number(url.searchParams.get("since") || "0");
    const rows = this.getRowsSince(since);
    return Response.json({ rows });
  }

  private mergeRows(incomingRows: Row[]): number {
    this.ensureTable();

    for (const row of incomingRows) {
      const dataStr = typeof row.data === "string" ? row.data : JSON.stringify(row.data);

      // LWW: only insert/update if incoming is newer
      this.state.storage.sql.exec(
        `INSERT INTO sync_rows (tbl, row_id, data, updated_at)
         VALUES (?, ?, ?, ?)
         ON CONFLICT (tbl, row_id) DO UPDATE SET
           data = excluded.data,
           updated_at = excluded.updated_at
         WHERE excluded.updated_at > sync_rows.updated_at`,
        row.table,
        row.id,
        dataStr,
        row.updated_at,
      );
    }

    // Return total row count
    const result = this.state.storage.sql.exec("SELECT COUNT(*) as cnt FROM sync_rows");
    for (const r of result) {
      return r.cnt as number;
    }
    return 0;
  }

  private getRowsSince(since: number): Row[] {
    this.ensureTable();

    const rows: Row[] = [];
    const result = this.state.storage.sql.exec(
      "SELECT tbl, row_id, data, updated_at FROM sync_rows WHERE updated_at > ?",
      since,
    );

    for (const r of result) {
      let data: Record<string, unknown> | string = r.data as string;
      // Try to parse if it's a JSON object (for unencrypted data)
      // Keep as string if it's encrypted (base64)
      try {
        const parsed = JSON.parse(data);
        if (typeof parsed === "object" && parsed !== null) {
          data = parsed;
        }
      } catch {
        // Keep as string (encrypted)
      }

      rows.push({
        table: r.tbl as string,
        id: r.row_id as string,
        data,
        updated_at: r.updated_at as number,
      });
    }

    return rows;
  }

  private broadcast(msg: Record<string, unknown>, exclude?: WebSocket): void {
    const payload = JSON.stringify(msg);
    for (const ws of this.state.getWebSockets()) {
      if (ws === exclude) continue;
      try {
        ws.send(payload);
      } catch {
        // Dead socket
      }
    }
  }
}
