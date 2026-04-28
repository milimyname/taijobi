import { Resvg } from '@resvg/resvg-js';
import { buildOgSvg } from '$lib/og-template';

export const prerender = true;

export const GET = async () => {
	const svg = buildOgSvg({
		heading: 'Vokabeln lernen, offline.',
		subtitle: 'Chinesisch · Englisch · Deutsch — lokal, ohne Konto',
		tag: 'Taijobi'
	});
	const png = new Resvg(svg, { fitTo: { mode: 'width', value: 1200 } }).render().asPng();
	return new Response(png as unknown as BodyInit, {
		headers: {
			'content-type': 'image/png',
			'cache-control': 'public, max-age=31536000, immutable'
		}
	});
};
