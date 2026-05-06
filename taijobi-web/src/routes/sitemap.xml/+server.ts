import { getCatalog } from '$lib/marketplace.remote';

export const prerender = true;

const ABS_URL = 'https://taijobi.com';

const STATIC_ROUTES = ['/', '/about', '/marketplace'];

export async function GET() {
	const catalog = await getCatalog();
	const today = new Date().toISOString().slice(0, 10);

	const urls = [
		...STATIC_ROUTES.map((path) => ({ loc: `${ABS_URL}${path}`, lastmod: today })),
		...catalog.map((entry) => ({
			loc: `${ABS_URL}/marketplace/${entry.id}`,
			lastmod: entry.added_at ?? today
		}))
	];

	const body = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${urls
	.map(
		(u) => `	<url>
		<loc>${u.loc}</loc>
		<lastmod>${u.lastmod}</lastmod>
	</url>`
	)
	.join('\n')}
</urlset>
`;

	return new Response(body, {
		headers: {
			'Content-Type': 'application/xml; charset=utf-8',
			'Cache-Control': 'public, max-age=3600'
		}
	});
}
