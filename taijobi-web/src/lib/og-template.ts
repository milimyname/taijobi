/**
 * Hand-written 1200×630 OG card. Renders to SVG; resvg rasterizes to PNG
 * at build time. No JSX, no satori, no font loading — system fonts only,
 * since the SVG goes through `<text>` elements that resvg shapes against
 * its bundled font fallback chain.
 *
 * Design language matches the in-app "Jade Garden" theme:
 *   primary  #195c37  (background)
 *   accent   #52b788  (subtitle)
 *   cream    #fefdfb  (heading)
 */

const W = 1200;
const H = 630;
const PRIMARY = '#195c37';
const PRIMARY_DARK = '#0d3a23';
const ACCENT = '#52b788';
const CREAM = '#fefdfb';

function escapeXml(s: string): string {
	return s
		.replace(/&/g, '&amp;')
		.replace(/</g, '&lt;')
		.replace(/>/g, '&gt;')
		.replace(/"/g, '&quot;')
		.replace(/'/g, '&apos;');
}

/** Wrap a long heading at ~22 chars per line, max 2 lines. */
function wrapHeading(text: string, maxChars = 22): string[] {
	if (text.length <= maxChars) return [text];
	const words = text.split(' ');
	const lines: string[] = [];
	let current = '';
	for (const w of words) {
		const next = current ? `${current} ${w}` : w;
		if (next.length > maxChars && current) {
			lines.push(current);
			current = w;
		} else {
			current = next;
		}
	}
	if (current) lines.push(current);
	return lines.slice(0, 2);
}

interface CardOptions {
	heading: string;
	subtitle?: string;
	tag?: string;
	brand?: string;
}

export function buildOgSvg({
	heading,
	subtitle = '',
	tag = '',
	brand = 'Taijobi'
}: CardOptions): string {
	const lines = wrapHeading(heading);
	const headingY = lines.length === 1 ? 320 : 260;
	const lineHeight = 110;

	const headingTspans = lines
		.map((line, i) => `<tspan x="80" y="${headingY + i * lineHeight}">${escapeXml(line)}</tspan>`)
		.join('');

	const subtitleEl = subtitle
		? `<text x="80" y="${headingY + lines.length * lineHeight + 30}" font-family="system-ui,-apple-system,Segoe UI,Roboto,sans-serif" font-size="42" font-weight="500" fill="${ACCENT}">${escapeXml(subtitle)}</text>`
		: '';

	const tagEl = tag
		? `
			<rect x="80" y="100" rx="32" ry="32" width="${30 + tag.length * 20}" height="56" fill="${ACCENT}" fill-opacity="0.2" stroke="${ACCENT}" stroke-width="2"/>
			<text x="${95}" y="138" font-family="system-ui,-apple-system,Segoe UI,Roboto,sans-serif" font-size="28" font-weight="700" letter-spacing="2" fill="${ACCENT}">${escapeXml(tag.toUpperCase())}</text>`
		: '';

	return `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">
	<defs>
		<linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
			<stop offset="0%" stop-color="${PRIMARY}"/>
			<stop offset="100%" stop-color="${PRIMARY_DARK}"/>
		</linearGradient>
	</defs>
	<rect width="${W}" height="${H}" fill="url(#bg)"/>
	<!-- watermark 學 -->
	<text x="${W - 60}" y="${H - 60}" font-family="PingFang SC,Noto Sans SC,sans-serif" font-size="540" font-weight="200" fill="${CREAM}" fill-opacity="0.05" text-anchor="end">學</text>

	${tagEl}

	<text font-family="system-ui,-apple-system,Segoe UI,Roboto,sans-serif" font-size="96" font-weight="900" fill="${CREAM}" letter-spacing="-2">${headingTspans}</text>

	${subtitleEl}

	<!-- brand pill bottom-right -->
	<text x="${W - 80}" y="${H - 60}" font-family="system-ui,-apple-system,Segoe UI,Roboto,sans-serif" font-size="32" font-weight="800" fill="${CREAM}" text-anchor="end">${escapeXml(brand)}</text>
</svg>`;
}
