/**
 * McpSession — Durable Object that keeps a warm WASM instance per sync key.
 *
 * One DO per sync key (keyed via `env.MCP_SESSION.idFromName(syncKey)`). The
 * DO:
 *   1. Lazily instantiates libtaijobi-mcp.wasm on the first POST.
 *   2. Pulls encrypted row state from the SyncRoom DO and decrypts into the
 *      in-memory SQLite via hanzi_apply_changes.
 *   3. Dispatches MCP JSON-RPC requests (initialize / tools/list / tools/call
 *      / ping) against the tool registry in mcp-tools.ts.
 *   4. For write tools, fire-and-forget pushes encrypted local mutations back
 *      to SyncRoom via state.waitUntil so the client response isn't blocked.
 *
 * Ported from wimg-sync/src/mcp-session.ts with the tool registry swapped out.
 */

import { WasmInstance, type SyncRow } from "./mcp-wasm";
import { getToolDefinitions, WRITE_TOOL_NAMES } from "./mcp-tools";

interface Env {
  SYNC_ROOM: DurableObjectNamespace;
}

interface JsonRpcRequest {
  jsonrpc: "2.0";
  id?: number | string;
  method: string;
  params?: Record<string, unknown>;
}

interface JsonRpcResponse {
  jsonrpc: "2.0";
  id?: number | string | null;
  result?: unknown;
  error?: { code: number; message: string; data?: unknown };
}

const REFRESH_INTERVAL_MS = 60_000; // Re-pull from SyncRoom every 60s on read

export class McpSession implements DurableObject {
  private syncKey: string | null = null;
  private wasm: WasmInstance | null = null;
  private encryptionKey: Uint8Array | null = null;
  private lastRefreshTs = 0;
  private lastSyncTs = 0;
  private sessionId: string | null = null;

  constructor(
    private state: DurableObjectState,
    private env: Env,
  ) {}

  async fetch(request: Request): Promise<Response> {
    if (request.method === "DELETE") {
      this.wasm?.close();
      this.wasm = null;
      this.encryptionKey = null;
      this.syncKey = null;
      this.sessionId = null;
      this.lastRefreshTs = 0;
      this.lastSyncTs = 0;
      return new Response("OK");
    }

    if (request.method !== "POST") {
      return Response.json(
        { jsonrpc: "2.0", error: { code: -32600, message: "Method not allowed" } },
        { status: 405 },
      );
    }

    const key = request.headers.get("X-Sync-Key");
    if (!key) {
      return Response.json(
        { jsonrpc: "2.0", error: { code: -32600, message: "Missing sync key" } },
        { status: 401 },
      );
    }

    if (!this.wasm || this.syncKey !== key) {
      try {
        await this.initialize(key);
      } catch (err) {
        const msg = err instanceof Error ? err.message : "Initialization failed";
        return Response.json(
          { jsonrpc: "2.0", error: { code: -32603, message: msg } },
          { status: 500 },
        );
      }
    }

    const clientSessionId = request.headers.get("Mcp-Session-Id");
    if (this.sessionId && clientSessionId && clientSessionId !== this.sessionId) {
      return new Response("Session not found", { status: 404 });
    }

    let rpc: JsonRpcRequest;
    try {
      rpc = (await request.json()) as JsonRpcRequest;
    } catch {
      return Response.json({
        jsonrpc: "2.0",
        id: null,
        error: { code: -32700, message: "Parse error" },
      });
    }

    // Notifications have no id — MCP spec says return 202 No Content.
    if (rpc.method === "notifications/initialized") {
      return new Response(null, { status: 202 });
    }

    // Refresh from SyncRoom on reads so the MCP sees fresh data. Writes use
    // local state (the WASM DB) and push after.
    if (!WRITE_TOOL_NAMES.has((rpc.params?.name as string) ?? "")) {
      const now = Date.now();
      if (now - this.lastRefreshTs > REFRESH_INTERVAL_MS) {
        try {
          await this.pullFromSync();
          this.lastRefreshTs = now;
        } catch {
          // Continue with stale data rather than failing the tool call.
        }
      }
    }

    const response = this.handleRpc(rpc);

    if (rpc.method === "initialize") {
      this.sessionId = crypto.randomUUID();
      return new Response(JSON.stringify(response), {
        headers: {
          "Content-Type": "application/json",
          "Mcp-Session-Id": this.sessionId,
        },
      });
    }

    return Response.json(response);
  }

  private async initialize(syncKey: string): Promise<void> {
    this.syncKey = syncKey;
    this.wasm = await WasmInstance.create();
    this.encryptionKey = this.wasm.deriveEncryptionKey(syncKey);
    await this.pullFromSync();
    this.lastRefreshTs = Date.now();
  }

  private async pullFromSync(): Promise<void> {
    if (!this.syncKey || !this.wasm || !this.encryptionKey) return;

    const stub = this.getSyncRoomStub();
    const url = `https://internal/sync/${this.syncKey}?since=${this.lastSyncTs}`;
    const res = await stub.fetch(
      new Request(url, {
        headers: { "X-Sync-Key": this.syncKey },
      }),
    );
    if (!res.ok) return;

    const { rows } = (await res.json()) as { rows: SyncRow[] };
    if (!rows.length) return;

    const decrypted = this.wasm.decryptRows(rows, this.encryptionKey);
    this.wasm.applyChanges(decrypted);

    const maxTs = rows.reduce((max, r) => Math.max(max, r.updated_at), this.lastSyncTs);
    this.lastSyncTs = maxTs;
  }

  private async pushToSync(): Promise<void> {
    if (!this.syncKey || !this.wasm || !this.encryptionKey) return;

    const rows = this.wasm.getChanges(this.lastSyncTs);
    if (!rows.length) return;

    const encrypted: SyncRow[] = rows.map((row) => ({
      ...row,
      data: this.wasm!.encryptField(
        JSON.stringify(row.data),
        this.encryptionKey!,
      ) as unknown as Record<string, unknown>,
    }));

    const stub = this.getSyncRoomStub();
    const res = await stub.fetch(
      new Request(`https://internal/sync/${this.syncKey}`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-Sync-Key": this.syncKey,
        },
        body: JSON.stringify({ rows: encrypted }),
      }),
    );

    if (!res.ok) {
      throw new Error(`Sync push failed: ${res.status}`);
    }

    const maxTs = rows.reduce((max, r) => Math.max(max, r.updated_at), this.lastSyncTs);
    this.lastSyncTs = maxTs;
  }

  private getSyncRoomStub() {
    const id = this.env.SYNC_ROOM.idFromName(this.syncKey!);
    return this.env.SYNC_ROOM.get(id);
  }

  private handleRpc(rpc: JsonRpcRequest): JsonRpcResponse {
    const { method, params, id } = rpc;

    switch (method) {
      case "initialize":
        return {
          jsonrpc: "2.0",
          id,
          result: {
            protocolVersion: "2025-03-26",
            capabilities: { tools: {} },
            serverInfo: { name: "taijobi", version: "0.1.0" },
          },
        };

      case "tools/list":
        return {
          jsonrpc: "2.0",
          id,
          result: {
            tools: getToolDefinitions().map((t) => ({
              name: t.name,
              description: t.description,
              inputSchema: {
                type: "object",
                properties: zodShapeToJsonSchema(t.schema),
              },
            })),
          },
        };

      case "tools/call":
        return this.handleToolCall(
          id,
          params as { name: string; arguments?: Record<string, unknown> },
        );

      case "ping":
        return { jsonrpc: "2.0", id, result: {} };

      default:
        return {
          jsonrpc: "2.0",
          id,
          error: { code: -32601, message: `Method not found: ${method}` },
        };
    }
  }

  private handleToolCall(
    id: number | string | undefined,
    params: { name: string; arguments?: Record<string, unknown> },
  ): JsonRpcResponse {
    const tools = getToolDefinitions();
    const tool = tools.find((t) => t.name === params.name);
    if (!tool) {
      return {
        jsonrpc: "2.0",
        id,
        error: { code: -32602, message: `Unknown tool: ${params.name}` },
      };
    }

    try {
      const result = tool.handler(params.arguments ?? {}, this.wasm!);

      if (WRITE_TOOL_NAMES.has(params.name)) {
        // Don't block the response on sync-push — let it finish in the
        // background via waitUntil.
        this.state.waitUntil(this.pushToSync());
      }

      return {
        jsonrpc: "2.0",
        id,
        result: {
          content: [{ type: "text", text: result.text }],
        },
      };
    } catch (err) {
      const msg = err instanceof Error ? err.message : "Tool execution failed";
      return {
        jsonrpc: "2.0",
        id,
        result: {
          content: [{ type: "text", text: JSON.stringify({ error: msg }) }],
          isError: true,
        },
      };
    }
  }
}

/**
 * Convert a shallow Zod schema map (e.g. `{ limit: z.number().optional() }`)
 * into a minimal JSON Schema `properties` object for MCP's tools/list.
 * Deliberately tiny — MCP clients mostly need type + description to prompt
 * the LLM correctly; full Zod→JSONSchema isn't worth the bundle weight here.
 */
function zodShapeToJsonSchema(
  schemas: Record<string, unknown>,
): Record<string, { type: string; description?: string }> {
  const result: Record<string, { type: string; description?: string }> = {};
  for (const [key, zodSchema] of Object.entries(schemas)) {
    const z = zodSchema as { _def?: { typeName?: string; description?: string } };
    let type = "string";
    if (z._def?.typeName === "ZodNumber") type = "number";
    if (z._def?.typeName === "ZodBoolean") type = "boolean";
    result[key] = { type, description: z._def?.description };
  }
  return result;
}
