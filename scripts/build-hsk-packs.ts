#!/usr/bin/env bun
/**
 * Convert drkameleon/complete-hsk-vocabulary JSON into taijobi pack format.
 * Generates one pack per HSK level (1-6 old).
 *
 * Usage:
 *   curl -sL https://raw.githubusercontent.com/drkameleon/complete-hsk-vocabulary/main/complete.json -o /tmp/hsk-complete.json
 *   bun scripts/build-hsk-packs.js /tmp/hsk-complete.json taijobi-web/static/packs/
 */

import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { join } from "node:path";

function convertLevel(levelStr) {
  const parts = levelStr.split("-");
  return { system: parts[0], num: parseInt(parts[1], 10) };
}

function main() {
  if (process.argv.length < 4) {
    console.error(`Usage: ${process.argv[1]} <complete.json> <output_dir>`);
    process.exit(1);
  }

  const data = JSON.parse(readFileSync(process.argv[2], "utf-8"));
  const outputDir = process.argv[3];
  mkdirSync(outputDir, { recursive: true });

  // Group by old HSK levels (1-6)
  const levels = new Map();
  for (const entry of data) {
    for (const levelStr of entry.level || []) {
      const { system, num } = convertLevel(levelStr);
      if (system === "old" && num >= 1 && num <= 6) {
        if (!levels.has(num)) levels.set(num, []);
        const form = entry.forms?.[0];
        if (!form) continue;
        levels.get(num).push({
          word: entry.simplified,
          pinyin: form.transcriptions?.pinyin || "",
          translation: (form.meanings || []).join("; "),
        });
      }
    }
  }

  const sortedKeys = [...levels.keys()].sort((a, b) => a - b);
  for (const levelNum of sortedKeys) {
    const words = levels.get(levelNum);
    const packId = `hsk-${levelNum}`;

    // Split into lessons of ~25 words each
    const lessonSize = 25;
    const lessons = [];
    for (let i = 0; i < words.length; i += lessonSize) {
      const chunk = words.slice(i, i + lessonSize);
      const lessonNum = Math.floor(i / lessonSize) + 1;
      lessons.push({
        id: `${packId}-${String(lessonNum).padStart(2, "0")}`,
        title: `HSK ${levelNum} - Teil ${lessonNum}`,
        sort_order: lessonNum,
        vocabulary: chunk,
      });
    }

    const pack = {
      id: packId,
      name: `HSK ${levelNum}`,
      version: 1,
      language_pair: "zh-en",
      lessons,
    };

    const outPath = join(outputDir, `${packId}.json`);
    writeFileSync(outPath, JSON.stringify(pack, null, 2) + "\n", "utf-8");

    const totalWords = lessons.reduce((s, l) => s + l.vocabulary.length, 0);
    console.log(
      `  ${packId}: ${totalWords} words, ${lessons.length} lessons -> ${outPath}`,
    );
  }

  console.log(`Done: ${levels.size} packs`);
}

main();
