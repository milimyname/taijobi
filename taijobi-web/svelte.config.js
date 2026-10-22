import adapter from '@sveltejs/adapter-static';

/** @type {import('@sveltejs/kit').Config} */
const config = {
	kit: {
		// Static output served by Caddy on the Hetzner VPS (infra/taijobi-web.caddy).
		// Every page is prerendered or client-only, so nothing runs per request.
		// With no server, hooks.server.ts is gone: the COOP/COEP headers OPFS
		// needs come from the Caddy fragment, and /data/*.bin dictionaries are
		// plain files on disk instead of an R2 proxy.
		adapter: adapter({
			// Not index.html: `/` is the prerendered landing page. Caddy falls
			// back to this shell for client-only routes (/character/X, …).
			fallback: '200.html',
			precompress: true
		}),
		output: {
			bundleStrategy: 'single'
		},
		prerender: {
			handleUnseenRoutes: 'ignore'
		},
		version: {
			pollInterval: 60 * 1000
		},
		experimental: {
			remoteFunctions: true
		}
	},
	compilerOptions: {
		experimental: {
			async: true
		}
	},
	vitePlugin: {
		dynamicCompileOptions: ({ filename }) =>
			filename.includes('node_modules') ? undefined : { runes: true }
	}
};

export default config;
