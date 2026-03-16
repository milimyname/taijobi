/// <reference lib="webworker" />

const sw = self as unknown as ServiceWorkerGlobalScope;
const CACHE_NAME = 'taijobi-v1';

const WASM_FILES = ['/libtaijobi.wasm'];

sw.addEventListener('install', (event) => {
	event.waitUntil(caches.open(CACHE_NAME).then((cache) => cache.addAll(WASM_FILES)));
	sw.skipWaiting();
});

sw.addEventListener('activate', (event) => {
	event.waitUntil(
		caches
			.keys()
			.then((keys) =>
				Promise.all(keys.filter((k) => k !== CACHE_NAME).map((k) => caches.delete(k)))
			)
	);
	sw.clients.claim();
});

sw.addEventListener('fetch', (event) => {
	const url = new URL(event.request.url);

	// Cache-first for WASM
	if (WASM_FILES.some((f) => url.pathname === f)) {
		event.respondWith(caches.match(event.request).then((cached) => cached ?? fetch(event.request)));
		return;
	}

	// Network-first for everything else
	event.respondWith(
		fetch(event.request).catch(() =>
			caches
				.match(event.request)
				.then((cached) => cached ?? new Response('Offline', { status: 503 }))
		)
	);
});
