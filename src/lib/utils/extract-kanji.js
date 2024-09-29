import fs from 'fs';
import path from 'path';
import { parse } from 'svg-parser';
import { fileURLToPath } from 'url';

// For ES modules, define __filename and __dirname
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Path to the directory containing kanji SVG files
const kanjiSvgDirectory = path.join(__dirname, '../../../kanjivg/kanji');

// Read all SVG filenames in the directory
const svgFiles = fs.readdirSync(kanjiSvgDirectory).filter((file) => file.endsWith('.svg'));

const kanjiData = {};

svgFiles.forEach((file) => {
	const filePath = path.join(kanjiSvgDirectory, file);
	const svgContent = fs.readFileSync(filePath, 'utf-8');
	const parsedSvg = parse(svgContent);

	// The root of the SVG structure
	const svgElement = parsedSvg.children[0];

	// Find the main <g> element containing the kanji strokes
	const kanjiGroup = svgElement.children.find(
		(child) =>
			child.type === 'element' && child.tagName === 'g' && child.properties?.id?.startsWith('kvg:'),
	);

	if (!kanjiGroup || !('children' in kanjiGroup)) {
		console.warn(`No kanji group found in ${file}`);
		return;
	}

	// Extract all <path> elements representing the strokes
	const strokePaths = extractStrokes(kanjiGroup);

	// Convert filename to actual kanji character
	const unicodeHex = file.replace('.svg', '').replace('u', '');
	const codePoint = parseInt(unicodeHex, 16);
	const kanjiCharacter = String.fromCodePoint(codePoint);

	kanjiData[kanjiCharacter] = strokePaths;
	console.log(`Extracted strokes for ${kanjiCharacter}`);
});

// Write the extracted data to a JSON file
const outputPath = path.join(__dirname, 'kanjiData.json');
fs.writeFileSync(outputPath, JSON.stringify(kanjiData, null, 2), 'utf-8');
console.log(`Kanji data saved to ${outputPath}`);

// Helper function to recursively extract stroke paths
function extractStrokes(element) {
	let strokes = [];

	if (element.type === 'element' && element.tagName === 'path') {
		const id = element.properties?.id;
		const d = element.properties?.d;
		if (id && d) {
			strokes.push({ id, d });
		}
	}

	if (element.children && element.children.length > 0) {
		element.children.forEach((child) => {
			strokes = strokes.concat(extractStrokes(child));
		});
	}

	return strokes;
}
