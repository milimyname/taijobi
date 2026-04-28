<script lang="ts">
	import '../../app.css';

	let { children } = $props();
</script>

<svelte:head>
	<style>
		body { font-family: system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; margin: 0; }
	</style>
</svelte:head>

<div class="min-h-screen bg-bg-light dark:bg-bg-dark">
	<nav class="sticky top-0 z-10 border-b border-slate-100 bg-bg-light/90 backdrop-blur-xl dark:border-white/5 dark:bg-bg-dark/90">
		<div class="mx-auto flex max-w-5xl items-center justify-between px-6 py-4">
			<a href="/" class="text-xl font-extrabold text-primary">Taijobi</a>
			<div class="flex items-center gap-1 sm:gap-2">
				<a
					href="/marketplace"
					class="rounded-full px-3 py-2 text-sm font-medium text-slate-700 transition-colors hover:bg-slate-100 dark:text-slate-200 dark:hover:bg-white/5"
				>
					Marktplatz
				</a>
				<a
					href="/about"
					class="rounded-full px-3 py-2 text-sm font-medium text-slate-700 transition-colors hover:bg-slate-100 dark:text-slate-200 dark:hover:bg-white/5"
				>
					&Uuml;ber
				</a>
				<a
					href="/home"
					class="rounded-full bg-primary px-4 py-2 text-sm font-bold text-white transition-colors hover:bg-primary/90"
				>
					App starten &rarr;
				</a>
			</div>
		</div>
	</nav>

	<main class="mx-auto max-w-5xl px-6 pb-20">
		{@render children()}
	</main>

	<footer class="border-t border-slate-100 dark:border-white/5">
		<div class="mx-auto flex max-w-5xl flex-wrap items-center justify-between gap-4 px-6 py-6 text-sm text-slate-500 dark:text-slate-400">
			<span>&copy; Taijobi &mdash; lokale Vokabel-App, offline-first</span>
			<div class="flex items-center gap-4">
				<a href="/" class="hover:text-primary">Start</a>
				<a href="/marketplace" class="hover:text-primary">Marktplatz</a>
				<a href="/about" class="hover:text-primary">&Uuml;ber</a>
				<a href="/home" class="hover:text-primary">App</a>
			</div>
		</div>
	</footer>
</div>
