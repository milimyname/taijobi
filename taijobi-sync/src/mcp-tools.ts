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
import { ID_REGEX, LANG_REGEX } from "../../packs/validator";
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
        "Install a content pack into the user's library. Use this when the user wants to turn structured vocabulary (e.g. OCR'd from a textbook photo, extracted from a PDF, or pasted as a list) into a proper pack — NOT individual lexicon entries. Common case: pass `vocabulary` as a real JSON array (one lesson). Multi-lesson case (e.g. a whole textbook): pass `lessons` as a real JSON array. Do NOT stringify the arrays — pass them as native JSON arrays in the tool call. Creates SQLite pack + lessons + cards in one transaction. Per-card language is auto-detected from the word's script, so Chinese / Arabic / German / English packs all tag correctly. The pack appears in /packs under 'Eigene' (tag='personal') and syncs privately to the user's other devices via their sync key.",
      schema: {
        name: z
          .string()
          .min(1)
          .max(120)
          .describe("Human-readable pack name shown in /packs (e.g. 'Long neu Kapitel 3')"),
        vocabulary: z
          .array(
            z.object({
              word: z.string().min(1).describe("The word / character / phrase"),
              pinyin: z.string().optional().describe("Pinyin (for Chinese)"),
              translation: z.string().optional().describe("Translation / gloss"),
            }),
          )
          .optional()
          .describe(
            "Flat vocabulary list for a single-lesson pack. Use this for the common case (a chapter, an image, a quick list). Mutually exclusive with `lessons`.",
          ),
        lessons: z
          .array(
            z.object({
              title: z.string().optional().describe("Lesson title"),
              vocabulary: z
                .array(
                  z.object({
                    word: z.string().min(1),
                    pinyin: z.string().optional(),
                    translation: z.string().optional(),
                  }),
                )
                .min(1),
            }),
          )
          .optional()
          .describe(
            "Multi-lesson pack structure. Only use when the user's content is naturally sub-divided (e.g. a whole textbook with multiple chapters). Otherwise use `vocabulary`.",
          ),
        id: z
          .string()
          .optional()
          .describe("Optional stable pack id. Auto-generated from timestamp if omitted."),
        language_pair: z
          .string()
          .optional()
          .describe(
            "Optional metadata hint (e.g. 'zh-en', 'ar-en'). Per-card language is auto-detected regardless.",
          ),
      },
      handler: (args, wasm) => {
        const name = String(args.name ?? "").trim();
        if (!name) throw new Error("name is empty");

        const packId = String(args.id ?? "").trim() || `mcp-${Date.now()}`;
        if (!ID_REGEX.test(packId)) {
          throw new Error(
            `id must match ${ID_REGEX.source} (lowercase letters, digits, dashes; got "${packId}")`,
          );
        }
        const languagePair =
          typeof args.language_pair === "string" && args.language_pair.length > 0
            ? args.language_pair
            : "zh-de";
        if (!LANG_REGEX.test(languagePair)) {
          throw new Error(
            `language_pair must match ${LANG_REGEX.source} (e.g. "zh-en", "de"; got "${languagePair}")`,
          );
        }

        type VocabItem = {
          word: string;
          pinyin: string | undefined;
          translation: string | undefined;
        };

        // LLM clients in the wild sometimes JSON-stringify nested array args
        // instead of passing them as real arrays. Accept both shapes so Claude
        // doesn't need to thread the needle.
        function coerceArray(raw: unknown, field: string): unknown[] {
          if (raw === undefined || raw === null) return [];
          if (Array.isArray(raw)) return raw;
          if (typeof raw === "string") {
            const trimmed = raw.trim();
            if (trimmed.length === 0) return [];
            try {
              const parsed = JSON.parse(trimmed);
              if (!Array.isArray(parsed)) {
                throw new Error(`${field}: JSON payload must be an array, got ${typeof parsed}`);
              }
              return parsed;
            } catch (err) {
              throw new Error(
                `${field}: string is not a valid JSON array — ${(err as Error).message}`,
              );
            }
          }
          throw new Error(`${field}: expected array, got ${typeof raw}`);
        }

        function normalizeVocab(raw: unknown[]): VocabItem[] {
          const out: VocabItem[] = [];
          for (const v of raw) {
            const rv = v as { word?: unknown; pinyin?: unknown; translation?: unknown };
            const word = typeof rv.word === "string" ? rv.word.trim() : "";
            if (!word) continue;
            out.push({
              word,
              pinyin: typeof rv.pinyin === "string" ? rv.pinyin : undefined,
              translation: typeof rv.translation === "string" ? rv.translation : undefined,
            });
          }
          return out;
        }

        // Normalize either shape into lessons[].vocabulary[]
        const rawLessons = coerceArray(args.lessons, "lessons");
        const flatVocab = normalizeVocab(coerceArray(args.vocabulary, "vocabulary"));

        let lessons: {
          id: string;
          title: string | undefined;
          sort_order: number;
          vocabulary: VocabItem[];
        }[];
        if (rawLessons.length > 0) {
          lessons = rawLessons.map((l, idx) => {
            const rl = l as { title?: unknown; name?: unknown; vocabulary?: unknown };
            // Accept `name` as alias for `title` — Claude occasionally mixes them up.
            const title =
              typeof rl.title === "string"
                ? rl.title
                : typeof rl.name === "string"
                  ? rl.name
                  : undefined;
            return {
              id: `${packId}-l${idx + 1}`,
              title,
              sort_order: idx + 1,
              vocabulary: normalizeVocab(coerceArray(rl.vocabulary, `lessons[${idx}].vocabulary`)),
            };
          });
        } else if (flatVocab.length > 0) {
          lessons = [{ id: `${packId}-l1`, title: name, sort_order: 1, vocabulary: flatVocab }];
        } else {
          throw new Error("provide either `vocabulary` or `lessons`");
        }

        const wordCount = lessons.reduce((n, l) => n + l.vocabulary.length, 0);
        if (wordCount === 0) throw new Error("no vocabulary entries");

        const pack = { id: packId, name, version: 1, language_pair: languagePair, lessons };
        wasm.installPack(JSON.stringify(pack));
        return ok({ pack_id: packId, name, word_count: wordCount, lessons: lessons.length });
      },
    },
  ];
}
