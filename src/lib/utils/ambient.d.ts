export type CropperDetails = {
	pixels: {
		width: number;
		height: number;
		x: number;
		y: number;
	};
};

export type KanjiObject = {
	ds: string[];
	grade: number;
	kunyomi: string[];
	meaning: string;
	onyomi: string[];
};

export type Card = {
	id: string;
	name: string;
	description: string;
	count: number;
	constant: boolean;
};

export type FlashcardType = {
	name: string;
	onyomi?: string;
	kunyomi?: string;
	meaning: string;
	notes?: string;
	customFurigana?: string;
	romanji?: string;
	id?: string;
	type?: string;
	furigana?: string;
	flashcardBox?: string;
};

export type ProgressDataItem = {
	name: string;
	score: number;
	meaning: string;
	onyomi: string;
	kunyomi: string;
};

export type KanjiInfo = {
	ds: string[];
	grade: number;
	meaning: string;
	onyomi: string[];
	kunyomi: string[];
};
