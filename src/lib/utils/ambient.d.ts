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
