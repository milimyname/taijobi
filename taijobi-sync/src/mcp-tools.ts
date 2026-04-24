/**
 * MCP tool definitions for taijobi.
 * 5 read tools + 3 write tools = 8 total.
 *
 * Each tool declares a shallow Zod schema for input (used by the LLM prompt
 * via tools/list) and a handler that maps to a WasmInstance method. Handlers
 * return `{ text }` with the JSON-stringified result — the session wraps it
 * as `{ content: [{ type: "text", text }] }` per MCP spec.
 */

import { z } from "zod";
import { validatePackLenient } from "../../packs/validator";
import type { WasmInstance } from "./mcp-wasm";

export interface ToolDefinition {
  name: string;
  description: string;
  schema: Record<string, z.ZodTypeAny>;
  handler: (args: Record<string, unknown>, wasm: WasmInstance) => { text: string };
}

/**
 * Tools that mutate state — the session pushes the resulting encrypted
 * changes back to SyncRoom via state.waitUntil after the handler runs.
 */
export const WRITE_TOOL_NAMES = new Set([
  "add_word",
  "import_kindle_clippings",
  "review_card",
  "install_pack",
  "add_lesson_to_pack",
]);

/** Stringify a tool result as compact JSON for the MCP text response. */
function ok<T>(value: T): { text: string } {
  return { text: JSON.stringify(value) };
}

export function getToolDefinitions(): ToolDefinition[] {
  return [
    // --- Read tools ---

    {
      name: "due_count",
      description:
        "Return the number of cards currently due for review. Optionally filter by pack id (e.g. 'hsk3') or 'lexicon' for personal words only.",
      schema: {
        filter: z.string().optional().describe("Pack id, 'lexicon', or omit for all cards"),
      },
      handler: (args, wasm) => {
        const filter = typeof args.filter === "string" ? args.filter : null;
        return ok({ due: wasm.getDueCount(filter) });
      },
    },

    {
      name: "get_due_cards",
      description:
        "Return cards currently due for review, with their word, language, pinyin, translation, and source pack. Use this when the user asks what to study next or wants to see what's due.",
      schema: {
        limit: z
          .number()
          .int()
          .min(1)
          .max(200)
          .optional()
          .describe("Max number of cards to return (default 20)"),
        filter: z.string().optional().describe("Pack id, 'lexicon', or omit for all cards"),
      },
      handler: (args, wasm) => {
        const limit = typeof args.limit === "number" ? args.limit : 20;
        const filter = typeof args.filter === "string" ? args.filter : null;
        const cards = wasm.getDueCards(limit, filter);
        return ok({ cards, count: cards.length });
      },
    },

    {
      name: "search_cards",
      description:
        "Search cards in the user's library by word, pinyin, or translation. Returns matching cards with metadata. Use when the user asks 'do I have X?' or wants to look up a specific word they've studied.",
      schema: {
        query: z.string().min(1).describe("Search query (word / pinyin / translation)"),
        limit: z.number().int().min(1).max(100).optional().describe("Max results (default 20)"),
      },
      handler: (args, wasm) => {
        const query = String(args.query ?? "");
        const limit = typeof args.limit === "number" ? args.limit : 20;
        const cards = wasm.searchCards(query, limit);
        return ok({ cards, count: cards.length });
      },
    },

    {
      name: "get_lexicon",
      description:
        "Return the user's personal lexicon — words they've collected while reading, with review state (reps, stability). Use when the user asks about their saved words or wants a vocabulary snapshot.",
      schema: {},
      handler: (_args, wasm) => {
        const entries = wasm.getLexicon();
        return ok({ entries, count: entries.length });
      },
    },

    {
      name: "list_packs",
      description:
        "List all installed content packs in the user's library (id, name, language_pair, word_count). ALWAYS call this before install_pack or add_lesson_to_pack so you can find the right existing pack instead of creating a duplicate one. If the user says something like 'I forgot these words for the Geld pack', look up the pack id here and use add_lesson_to_pack.",
      schema: {},
      handler: (_args, wasm) => {
        const packs = wasm.getPacks();
        return ok({ packs, count: packs.length });
      },
    },

    {
      name: "get_stats",
      description:
        "Return study statistics: daily review counts + accuracy for the last N days, rating distribution, current streak, longest streak. Use when the user asks how they're doing or for a progress summary.",
      schema: {
        days: z
          .number()
          .int()
          .min(1)
          .max(365)
          .optional()
          .describe("Days of history to include (default 30)"),
      },
      handler: (args, wasm) => {
        const days = typeof args.days === "number" ? args.days : 30;
        return ok(wasm.getStats(days));
      },
    },

    // --- Write tools ---

    {
      name: "add_word",
      description:
        "Add a single word to the user's personal lexicon. Language is auto-detected (Chinese / German / English / Arabic / etc.). Chinese words are enriched from CC-CEDICT, English from Wiktionary, German from Wiktionary. Idempotent — adding a word that already exists is a no-op.",
      schema: {
        word: z.string().min(1).describe("The word to add"),
      },
      handler: (args, wasm) => {
        const word = String(args.word ?? "").trim();
        if (!word) throw new Error("word is empty");
        return ok(wasm.addWord(word));
      },
    },

    {
      name: "import_kindle_clippings",
      description:
        "Parse a Kindle `My Clippings.txt` file and bulk-add every highlight to the personal lexicon in one transaction. Bookmarks are skipped. Duplicates are counted but not re-added. Use when the user pastes their clippings file content directly.",
      schema: {
        raw: z
          .string()
          .min(1)
          .describe("Full My Clippings.txt contents (the `==========` delimited format)"),
      },
      handler: (args, wasm) => {
        const raw = String(args.raw ?? "");
        if (!raw) throw new Error("raw is empty");
        const clippings = wasm.parseKindle(raw);
        if (clippings.length === 0) {
          return ok({ parsed: 0, added: 0, skipped: 0, failed: 0, books: 0 });
        }
        const words = clippings.map((c) => c.text);
        const bulk = wasm.bulkAddLexicon(words);
        const books = new Set(clippings.map((c) => c.book)).size;
        return ok({ parsed: clippings.length, ...bulk, books });
      },
    },

    {
      name: "review_card",
      description:
        "Record a review for a card. Rating is 1 (Again) / 2 (Hard) / 3 (Good) / 4 (Easy). The FSRS scheduler uses this to plan the next review. Call after the user self-assesses how well they remembered.",
      schema: {
        id: z.string().min(1).describe("Card id (from get_due_cards)"),
        rating: z
          .number()
          .int()
          .min(1)
          .max(4)
          .describe("FSRS rating: 1 Again / 2 Hard / 3 Good / 4 Easy"),
      },
      handler: (args, wasm) => {
        const id = String(args.id ?? "");
        const rating = Number(args.rating ?? 0);
        if (!id) throw new Error("id is empty");
        if (rating < 1 || rating > 4) throw new Error("rating must be 1..4");
        wasm.reviewCard(id, rating);
        return ok({ reviewed: id, rating });
      },
    },

    {
      name: "install_pack",
      description:
        'Install a content pack into the user\'s library. Use for structured vocabulary (OCR from a textbook, PDF chapter, pasted list) — NOT for single words (use add_word). Input is a single JSON string matching the shape of packs/official/hsk-1.json. Example:\n{"id":"mein-pack","name":"Kapitel 3","version":1,"language_pair":"zh-de","lessons":[{"id":"mein-pack-l1","title":"Geld & Zahlen","sort_order":1,"vocabulary":[{"word":"人民币","pinyin":"Rénmínbì","translation":"RMB"}]}]}\nRules: `id` and every `lessons[].id` match ^[a-z0-9][a-z0-9-]*$. `language_pair` like "zh-de" / "ar-en". `translation` is optional — partial packs are fine (words can be filled in later). Per-card language auto-detected from the word\'s script. Appears in /packs under \'Eigene\' (tag=personal) and syncs privately to the user\'s other devices.',
      schema: {
        pack_json: z
          .string()
          .min(1)
          .describe(
            "Full pack JSON as a single string. Must match packs/official/hsk-1.json structure — see the example in the tool description.",
          ),
      },
      handler: (args, wasm) => {
        const raw = String(args.pack_json ?? "").trim();
        if (!raw) throw new Error("pack_json is empty");

        let parsed: unknown;
        try {
          parsed = JSON.parse(raw);
        } catch (err) {
          throw new Error(`pack_json: invalid JSON — ${(err as Error).message}`);
        }

        const pack = validatePackLenient(parsed);
        wasm.installPack(JSON.stringify(pack));
        const wordCount = pack.lessons.reduce((n, l) => n + l.vocabulary.length, 0);
        return ok({
          pack_id: pack.id,
          name: pack.name,
          word_count: wordCount,
          lessons: pack.lessons.length,
        });
      },
    },

    {
      name: "add_lesson_to_pack",
      description:
        'Append a single lesson (with its vocabulary) to an EXISTING pack — non-destructively. Use this when the user mentions they forgot some words that belong in a pack you (or they) already created; creating a new pack in that case leaves duplicate entries in /packs. Always call list_packs first to find the correct pack_id.\nInput: pack_id + lesson_json (a single lesson object). Example:\n{"pack_id":"chinesisch-geld-zimmer","lesson_json":"{\\"id\\":\\"chinesisch-geld-zimmer-l4\\",\\"title\\":\\"Bank\\",\\"sort_order\\":4,\\"vocabulary\\":[{\\"word\\":\\"银行\\",\\"pinyin\\":\\"yínháng\\",\\"translation\\":\\"Bank\\"}]}"}\nRules: lesson_id must match ^[a-z0-9][a-z0-9-]*$ and must be unique within the pack (upsert — re-using an existing lesson_id just updates its metadata and merges new vocab). Existing cards keep their FSRS/review state. Partial packs are fine; translation is optional.',
      schema: {
        pack_id: z
          .string()
          .min(1)
          .describe("Id of an existing pack (from list_packs)"),
        lesson_json: z
          .string()
          .min(1)
          .describe(
            "Single lesson JSON: {id, title?, sort_order, vocabulary: [{word, pinyin?, translation?}]}",
          ),
      },
      handler: (args, wasm) => {
        const packId = String(args.pack_id ?? "").trim();
        const raw = String(args.lesson_json ?? "").trim();
        if (!packId) throw new Error("pack_id is empty");
        if (!raw) throw new Error("lesson_json is empty");

        let parsed: unknown;
        try {
          parsed = JSON.parse(raw);
        } catch (err) {
          throw new Error(`lesson_json: invalid JSON — ${(err as Error).message}`);
        }

        // Shape check — keep it shallow; Zig re-parses for insertion and
        // returns "invalid lesson JSON" on semantic problems.
        if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
          throw new Error("lesson_json must be an object");
        }
        const lesson = parsed as Record<string, unknown>;
        if (typeof lesson.id !== "string" || !/^[a-z0-9][a-z0-9-]*$/.test(lesson.id)) {
          throw new Error("lesson.id must match ^[a-z0-9][a-z0-9-]*$");
        }
        if (!Array.isArray(lesson.vocabulary) || lesson.vocabulary.length === 0) {
          throw new Error("lesson.vocabulary must be a non-empty array");
        }

        wasm.addLessonToPack(packId, JSON.stringify(lesson));
        return ok({
          pack_id: packId,
          lesson_id: lesson.id,
          added: (lesson.vocabulary as unknown[]).length,
        });
      },
    },
  ];
}
