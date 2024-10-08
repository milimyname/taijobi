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
	romaji?: string;
	id?: string;
	type?: string;
	furigana?: string;
	flashcardBox?: string;
	partOfSpeech?: verb | adjective | unknown;
	user?: string;
};

export type ProgressDataItem = {
	name: string;
	score: number;
	meaning?: string;
	onyomi?: string;
	kunyomi?: string;
};

export type KanjiInfo = {
	ds: string[];
	grade: number;
	meaning: string;
	onyomi: string[];
	kunyomi: string[];
};

export type TypeToZod<T> = Required<{
	[K in keyof T]: T[K] extends string | number | boolean | null | undefined
		? undefined extends T[K]
			? z.ZodDefault<z.ZodType<Exclude<T[K], undefined>>>
			: z.ZodType<T[K]>
		: z.ZodObject<TypeToZod<T[K]>>;
}>;
