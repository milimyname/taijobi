import tailwindcss from '@tailwindcss/vite';
import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';

export default defineConfig({
	plugins: [
		tailwindcss(),
		sveltekit(),
		{
			name: 'coop-coep-headers',
			configureServer(server) {
				server.middlewares.use((_req, res, next) => {
					res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
					res.setHeader('Cross-Origin-Embedder-Policy', 'require-corp');
					next();
				});
			},
		},
	],
});
