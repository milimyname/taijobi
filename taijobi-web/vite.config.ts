import tailwindcss from '@tailwindcss/vite';
import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';
import pkg from './package.json' with { type: 'json' };

function coopCoep(
	_req: unknown,
	res: { setHeader(name: string, value: string): void },
	next: () => void
) {
	res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
	res.setHeader('Cross-Origin-Embedder-Policy', 'require-corp');
	next();
}

export default defineConfig({
	define: {
		__APP_VERSION__: JSON.stringify(pkg.version)
	},
	plugins: [
		tailwindcss(),
		sveltekit(),
		{
			// Prod sets these in infra/taijobi-web.caddy; dev + preview set them here.
			name: 'coop-coep-headers',
			configureServer(server) {
				server.middlewares.use(coopCoep);
			},
			configurePreviewServer(server) {
				server.middlewares.use(coopCoep);
			}
		}
	]
});
