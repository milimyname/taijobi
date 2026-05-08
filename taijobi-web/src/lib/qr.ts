import { renderSVG } from 'uqr';

/**
 * Pool of taijobi-flavoured hanzi for the QR overlay. Picked at random per
 * generation so each share has a tiny bit of personality. All have a
 * pedagogical / linguistic vibe so they fit the app's brand.
 */
const OVERLAY_HANZI = ['学', '习', '字', '词', '语', '文', '书', '中', '汉', '日'];

const PRIMARY = '#195c37'; // Jade Garden brand colour
const CREAM = '#fefdfb'; // Match warm-cream surface

/**
 * Generate a QR-code SVG branded for taijobi:
 *   - jade-green modules instead of pure black
 *   - cream background to match the rest of the app
 *   - small jade-rimmed circle in the centre with a random hanzi overlay
 *   - error-correction level H (~30% recoverable) so the overlay doesn't
 *     break scannability
 */
export function generateQRSvg(text: string): string {
	const svg = renderSVG(text, {
		blackColor: PRIMARY,
		whiteColor: CREAM,
		ecc: 'H',
		border: 2
	});

	// Pull the viewBox so we can drop the overlay at the centre regardless
	// of the QR's actual module count (which depends on payload length).
	const vbMatch = svg.match(/viewBox="(-?\d+\s+-?\d+\s+\d+\s+\d+)"/);
	if (!vbMatch) return svg;
	const [, , width] = vbMatch[1].split(/\s+/).map(Number);
	const cx = width / 2;
	const radius = width * 0.13;
	const fontSize = radius * 1.5;

	const char = OVERLAY_HANZI[Math.floor(Math.random() * OVERLAY_HANZI.length)];

	const overlay =
		`<circle cx="${cx}" cy="${cx}" r="${radius}" fill="${CREAM}" stroke="${PRIMARY}" stroke-width="0.6"/>` +
		`<text x="${cx}" y="${cx}" text-anchor="middle" dominant-baseline="central" ` +
		`font-size="${fontSize}" fill="${PRIMARY}" font-weight="700" ` +
		`font-family="'PingFang SC','Hiragino Sans GB','Noto Sans SC',sans-serif">${char}</text>`;

	return svg.replace('</svg>', overlay + '</svg>');
}
