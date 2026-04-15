/// <reference types="@sveltejs/kit" />
/// <reference no-default-lib="true"/>
/// <reference lib="esnext" />
/// <reference lib="webworker" />

import { build, files, version } from '$service-worker';

declare const self: ServiceWorkerGlobalScope;

const CACHE = `taijobi-${version}`;
// libtaijobi.wasm and /data/*.bin files are never cached by the SW — they
// change independently of the JS build (a Zig-only rebuild leaves `version`
// the same), and a stale WASM served from the SW cache silently breaks new
// C-ABI exports until the user manually unregisters the SW. Leaving them
// out of the precache lets the browser HTTP cache handle freshness, with
// 304 Not Modified for unchanged builds.
const ASSETS = [...build, ...files.filter((f) => f !== '/libtaijobi.wasm')];

// Install: precache JS/CSS/icons (not WASM, not dictionary .bin files)
self.addEventListener('install', (event) => {
	event.waitUntil(caches.open(CACHE).then((cache) => cache.addAll([...ASSETS, '/'])));
});

// Activate: delete old caches + purge any stale .bin or .wasm entries that
// previous SW versions may have cached, then claim clients.
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
								return (
									(u.pathname.startsWith('/data/') && u.pathname.endsWith('.bin')) ||
									u.pathname === '/libtaijobi.wasm'
								);
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

	// Skip the Zig WASM binary — see the comment above ASSETS. Letting the
	// browser hit the network (or its HTTP cache) means a Zig-only rebuild
	// reaches the user on next reload instead of waiting for an SW bump.
	if (url.pathname === '/libtaijobi.wasm') {
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
