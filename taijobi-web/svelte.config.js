import adapter from '@sveltejs/adapter-cloudflare';

/** @type {import('@sveltejs/kit').Config} */
const config = {
	kit: {
		adapter: adapter(),
		output: {
			bundleStrategy: 'single'
		},
		prerender: {
			handleUnseenRoutes: 'ignore'
		},
		version: {
			pollInterval: 5 * 60 * 1000
		}
	},
	vitePlugin: {
		dynamicCompileOptions: ({ filename }) =>
			filename.includes('node_modules') ? undefined : { runes: true }
	}
};

export default config;
