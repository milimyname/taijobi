// kanji.d.ts
export interface KanjiInfo {
	ds: string[];
	grade: number;
	meaning: string;
	onyomi: string[];
	kunyomi: string[];
}

export interface KanjiDictionary {
	[key: string]: KanjiInfo;
}

export const kanji: KanjiDictionary;
