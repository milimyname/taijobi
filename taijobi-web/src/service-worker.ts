/// <reference types="@sveltejs/kit" />
/// <reference no-default-lib="true"/>
/// <reference lib="esnext" />
/// <reference lib="webworker" />

import { build, files, version } from '$service-worker';

declare const self: ServiceWorkerGlobalScope;

const CACHE = `taijobi-${version}`;
const ASSETS = [...build, ...files];

// Install: precache all assets
self.addEventListener('install', (event) => {
	event.waitUntil(caches.open(CACHE).then((cache) => cache.addAll([...ASSETS, '/'])));
});

// Activate: delete old caches, claim clients
self.addEventListener('activate', (event) => {
	event.waitUntil(
		caches
			.keys()
			.then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
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
	if (event.request.method !== 'GET' || url.origin !== self.location.origin) return;

	// Cache-first for precached assets (WASM, JS, CSS, icons)
	if (ASSETS.includes(url.pathname)) {
		event.respondWith(
			caches.match(event.request).then(
				(cached) =>
					cached ??
					fetch(event.request).then((response) => {
						caches.open(CACHE).then((cache) => cache.put(event.request, response.clone()));
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
					caches.open(CACHE).then((cache) => cache.put(event.request, response.clone()));
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
				if (response.ok) {
					caches.open(CACHE).then((cache) => cache.put(event.request, response.clone()));
				}
				return response;
			})
			.catch(async () => {
				return (
					(await caches.match(event.request)) ?? new Response('Offline', { status: 503 })
				);
			})
	);
});
