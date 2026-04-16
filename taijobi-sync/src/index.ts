import { Hono } from "hono";
import { cors } from "hono/cors";

export { SyncRoom } from "./sync-room";
export { McpSession } from "./mcp-session";

type Bindings = {
  SYNC_ROOM: DurableObjectNamespace;
  MCP_SESSION: DurableObjectNamespace;
};

const ALLOWED_ORIGINS = [
  "https://taijobi.pages.dev",
  "https://taijobi.com",
  "https://www.taijobi.com",
  "http://localhost:5173",
  "http://localhost:4173",
];

const app = new Hono<{ Bindings: Bindings }>();

app.use(
  "*",
  cors({
    origin: (origin) => {
      if (!origin) return "*";
      if (ALLOWED_ORIGINS.includes(origin)) return origin;
      if (origin.endsWith(".pages.dev")) return origin;
      // Allow private network origins for local dev
      if (/^https?:\/\/(192\.168\.|10\.|172\.(1[6-9]|2\d|3[01])\.|localhost)/.test(origin))
        return origin;
      return "";
    },
    allowMethods: ["GET", "POST", "DELETE", "OPTIONS"],
    allowHeaders: ["Content-Type", "Authorization", "Mcp-Session-Id"],
    exposeHeaders: ["Mcp-Session-Id"],
  }),
);

function getSyncRoom(env: Bindings, key: string) {
  const id = env.SYNC_ROOM.idFromName(key);
  return env.SYNC_ROOM.get(id);
}

// WebSocket upgrade — route to DO
app.get("/ws/:key", async (c) => {
  const key = c.req.param("key");
  const upgradeHeader = c.req.header("Upgrade");

  if (!upgradeHeader || upgradeHeader.toLowerCase() !== "websocket") {
    return c.text("Expected WebSocket upgrade", 426);
  }

  const stub = getSyncRoom(c.env, key);
  const url = new URL(c.req.url);
  url.pathname = "/ws";

  return stub.fetch(
    new Request(url.toString(), {
      headers: {
        Upgrade: "websocket",
        "X-Sync-Key": key,
      },
    }),
  );
});

// Push changed rows — route to DO
app.post("/sync/:key", async (c) => {
  const key = c.req.param("key");
  const stub = getSyncRoom(c.env, key);

  return stub.fetch(
    new Request(c.req.url, {
      method: "POST",
      headers: { "Content-Type": "application/json", "X-Sync-Key": key },
      body: c.req.raw.body,
    }),
  );
});

// Pull rows newer than `since` — route to DO
app.get("/sync/:key", async (c) => {
  const key = c.req.param("key");
  const stub = getSyncRoom(c.env, key);

  const url = new URL(c.req.url);
  return stub.fetch(
    new Request(url.toString(), {
      headers: { "X-Sync-Key": key },
    }),
  );
});

// --- MCP server (Phase 6.2) ---

/** Extract Bearer token from Authorization header. */
function extractBearerToken(header: string | undefined): string | null {
  if (!header) return null;
  const match = header.match(/^Bearer\s+(.+)$/i);
  return match?.[1] ?? null;
}

/** Get the McpSession DO stub keyed by sync key. One DO per key so the
 *  decrypted in-memory DB stays warm between tool calls. */
function getMcpSession(env: Bindings, key: string) {
  const id = env.MCP_SESSION.idFromName(key);
  return env.MCP_SESSION.get(id);
}

// MCP doesn't support SSE in this server — reject GET.
app.get("/mcp", (c) => c.text("Method Not Allowed", 405));

// MCP JSON-RPC endpoint (Streamable HTTP transport).
app.post("/mcp", async (c) => {
  const syncKey = extractBearerToken(c.req.header("Authorization"));
  if (!syncKey) {
    return c.json(
      {
        jsonrpc: "2.0",
        id: null,
        error: { code: -32600, message: "Missing Authorization: Bearer <sync-key>" },
      },
      401,
    );
  }

  const stub = getMcpSession(c.env, syncKey);

  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    "X-Sync-Key": syncKey,
  };
  const sessionId = c.req.header("Mcp-Session-Id");
  if (sessionId) headers["Mcp-Session-Id"] = sessionId;
  const accept = c.req.header("Accept");
  if (accept) headers["Accept"] = accept;

  return stub.fetch(
    new Request(c.req.url, {
      method: "POST",
      headers,
      body: c.req.raw.body,
    }),
  );
});

// Evict MCP session (drops the warm WASM instance).
app.delete("/mcp", async (c) => {
  const syncKey = extractBearerToken(c.req.header("Authorization"));
  if (!syncKey) return c.text("Missing Authorization", 401);

  const stub = getMcpSession(c.env, syncKey);

  const headers: Record<string, string> = { "X-Sync-Key": syncKey };
  const sessionId = c.req.header("Mcp-Session-Id");
  if (sessionId) headers["Mcp-Session-Id"] = sessionId;

  return stub.fetch(
    new Request(c.req.url, {
      method: "DELETE",
      headers,
    }),
  );
});

export default app;
