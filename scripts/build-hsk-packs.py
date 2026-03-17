#!/usr/bin/env python3
"""
Convert drkameleon/complete-hsk-vocabulary JSON into taijobi pack format.
Generates one pack per HSK level (1-6 old, 1-9 new).

Usage:
  curl -sL https://raw.githubusercontent.com/drkameleon/complete-hsk-vocabulary/main/complete.json -o /tmp/hsk-complete.json
  python3 scripts/build-hsk-packs.py /tmp/hsk-complete.json taijobi-web/static/packs/
"""

import json
import os
import sys


def convert_level(level_str: str) -> tuple[str, int]:
    """Convert 'old-3' or 'new-4' to (system, level_num)."""
    parts = level_str.split('-')
    return parts[0], int(parts[1])


def main():
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <complete.json> <output_dir>")
        sys.exit(1)

    with open(sys.argv[1], 'r', encoding='utf-8') as f:
        data = json.load(f)

    output_dir = sys.argv[2]
    os.makedirs(output_dir, exist_ok=True)

    # Group by old HSK levels (1-6) for now
    levels: dict[int, list] = {}
    for entry in data:
        for level_str in entry.get('level', []):
            system, num = convert_level(level_str)
            if system == 'old' and 1 <= num <= 6:
                if num not in levels:
                    levels[num] = []
                form = entry['forms'][0] if entry.get('forms') else None
                if not form:
                    continue
                word = {
                    'word': entry['simplified'],
                    'pinyin': form['transcriptions'].get('pinyin', ''),
                    'translation': '; '.join(form.get('meanings', [])),
                }
                levels[num].append(word)

    for level_num, words in sorted(levels.items()):
        pack_id = f'hsk-{level_num}'
        # Split into lessons of ~25 words each
        lesson_size = 25
        lessons = []
        for i in range(0, len(words), lesson_size):
            chunk = words[i:i + lesson_size]
            lesson_num = (i // lesson_size) + 1
            lessons.append({
                'id': f'{pack_id}-{lesson_num:02d}',
                'title': f'HSK {level_num} - Teil {lesson_num}',
                'sort_order': lesson_num,
                'vocabulary': chunk,
            })

        pack = {
            'id': pack_id,
            'name': f'HSK {level_num}',
            'version': 1,
            'language_pair': 'zh-en',
            'lessons': lessons,
        }

        out_path = os.path.join(output_dir, f'{pack_id}.json')
        with open(out_path, 'w', encoding='utf-8') as f:
            json.dump(pack, f, ensure_ascii=False, indent=2)

        total_words = sum(len(l['vocabulary']) for l in lessons)
        print(f"  {pack_id}: {total_words} words, {len(lessons)} lessons -> {out_path}")

    print(f"Done: {len(levels)} packs")


if __name__ == '__main__':
    main()
