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

export type Ctx = {
	strokeStyle: string;
	beginPath: () => void;
	moveTo: (arg0: number, arg1: number) => void;
	lineTo: (arg0: number, arg1: number) => void;
	stroke: () => void;
	lineWidth: number;
	lineJoin: string;
	lineCap: string;
	clearRect: (arg0: number, arg1: number, arg2: number, arg3: number) => void;
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
	onyomi: string;
	kunyomi: string;
	meaning: string;
};

export type ProgressDataItem = {
	name: string;
	score: number;
	meaning: string;
	onyomi: string;
	kunyomi: string;
};
