/// <reference types="@sveltejs/kit" />
/// <reference no-default-lib="true"/>
/// <reference lib="esnext" />
/// <reference lib="webworker" />

import { build, files, version } from '$service-worker';

declare const self: ServiceWorkerGlobalScope;

const CACHE = `taijobi-${version}`;
const ASSETS = [...build, ...files];

// Install: precache all assets — including libtaijobi.wasm so a first-install
// still works offline. Freshness for the WASM is handled at fetch time
// (network-first) rather than at SW-version time, because Zig-only rebuilds
// don't change the SW `version` hash.
self.addEventListener('install', (event) => {
	event.waitUntil(caches.open(CACHE).then((cache) => cache.addAll([...ASSETS, '/'])));
});

// Activate: delete old caches + purge /data/*.bin entries (OPFS is their
// cache layer, the SW cache would just duplicate storage). We deliberately
// do NOT purge libtaijobi.wasm — it's the offline fallback for the fetch
// handler below.
self.addEventListener('activate', (event) => {
	event.waitUntil(
		caches
			.keys()
			.then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
			.then(() => caches.open(CACHE))
			.then((cache) =>
				cache.keys().then((requests) =>
					Promise.all(
						requests
							.filter((r) => {
								const u = new URL(r.url);
								return u.pathname.startsWith('/data/') && u.pathname.endsWith('.bin');
							})
							.map((r) => cache.delete(r))
					)
				)
			)
			.then(() => self.clients.claim())
	);
});

// SKIP_WAITING message from update banner
self.addEventListener('message', (event) => {
	if (event.data?.type === 'SKIP_WAITING') {
		self.skipWaiting();
	}
});

self.addEventListener('fetch', (event) => {
	const url = new URL(event.request.url);
	if (event.request.method !== 'GET') return;
	// Skip cross-origin and sync API requests (WebSocket upgrades, API calls)
	if (url.origin !== self.location.origin) return;

	// Skip caching for Chinese data files — OPFS is the cache layer
	if (url.pathname.startsWith('/data/') && url.pathname.endsWith('.bin')) {
		return;
	}

	// Network-first for the Zig WASM binary. Zig-only rebuilds don't bump the
	// SW `version` hash, so a cache-first strategy would keep serving the old
	// WASM until the user manually unregisters the SW (silently breaking new
	// C-ABI exports). Network-first picks up the fresh build on any online
	// reload; the cached copy stays as the offline fallback.
	if (url.pathname === '/libtaijobi.wasm') {
		event.respondWith(
			fetch(event.request)
				.then((response) => {
					if (response.ok) {
						const clone = response.clone();
						caches.open(CACHE).then((cache) => cache.put(event.request, clone));
					}
					return response;
				})
				.catch(async () => {
					const cached = await caches.match(event.request);
					return cached ?? new Response('Offline', { status: 503 });
				})
		);
		return;
	}

	// Cache-first for precached assets (WASM, JS, CSS, icons)
	if (ASSETS.includes(url.pathname)) {
		event.respondWith(
			caches.match(event.request).then(
				(cached) =>
					cached ??
					fetch(event.request).then((response) => {
						const clone = response.clone();
						caches.open(CACHE).then((cache) => cache.put(event.request, clone));
						return response;
					})
			) as Promise<Response>
		);
		return;
	}

	// Network-first for navigation (HTML pages)
	if (event.request.mode === 'navigate') {
		event.respondWith(
			fetch(event.request)
				.then((response) => {
					const clone = response.clone();
					caches.open(CACHE).then((cache) => cache.put(event.request, clone));
					return response;
				})
				.catch(async () => {
					const cached = await caches.match(event.request);
					return cached ?? (await caches.match('/')) ?? new Response('Offline', { status: 503 });
				})
		);
		return;
	}

	// Network-first for everything else
	event.respondWith(
		fetch(event.request)
			.then((response) => {
				if (response.ok && response.type === 'basic') {
					const clone = response.clone();
					caches.open(CACHE).then((cache) => cache.put(event.request, clone));
				}
				return response;
			})
			.catch(async () => {
				return (await caches.match(event.request)) ?? new Response('Offline', { status: 503 });
			})
	);
});
