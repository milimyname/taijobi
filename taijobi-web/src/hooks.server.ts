import type { Handle } from '@sveltejs/kit';

/**
 * Serve dictionary .bin files from R2 bucket.
 * Requests to /data/*.bin are proxied to the taijobi-data R2 bucket.
 * Files: cedict.bin, decomp.bin, strokes.bin, endict.bin, dedict.bin
 */
export const handle: Handle = async ({ event, resolve }) => {
	const { pathname } = event.url;

	// Only intercept /data/*.bin requests
	if (pathname.startsWith('/data/') && pathname.endsWith('.bin')) {
		const key = pathname.slice(1); // "data/endict.bin"

		try {
			const bucket = event.platform?.env?.DATA_BUCKET;
			if (!bucket) {
				// No R2 binding (dev mode) — fall through to static assets
				return resolve(event);
			}

			// Handle HEAD requests (used for progress estimation)
			if (event.request.method === 'HEAD') {
				const head = await bucket.head(key);
				if (!head) return new Response(null, { status: 404 });
				return new Response(null, {
					headers: {
						'content-length': String(head.size),
						'content-type': 'application/octet-stream',
						'cache-control': 'public, max-age=604800, immutable'
					}
				});
			}

			const object = await bucket.get(key);
			if (!object) return new Response('Not found', { status: 404 });

			return new Response(object.body, {
				headers: {
					'content-type': 'application/octet-stream',
					'content-length': String(object.size),
					'cache-control': 'public, max-age=604800, immutable'
				}
			});
		} catch (e) {
			console.error(`[r2] Failed to serve ${key}:`, e);
			// Fall through to static assets / 404
			return resolve(event);
		}
	}

	return resolve(event);
};
