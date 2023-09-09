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
};
