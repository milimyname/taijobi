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
		<div class="mx-auto flex max-w-5xl items-center justify-between gap-2 px-4 py-3 sm:px-6 sm:py-4">
			<a href="/" class="shrink-0 text-lg font-extrabold text-primary sm:text-xl">Taijobi</a>
			<div class="flex items-center gap-0.5 sm:gap-2">
				<a
					href="/marketplace"
					class="rounded-full px-2 py-2 text-xs font-medium text-slate-600 transition-colors hover:bg-slate-100 dark:text-slate-300 dark:hover:bg-white/5 sm:px-3 sm:text-sm sm:text-slate-700 sm:dark:text-slate-200"
				>
					Marktplatz
				</a>
				<a
					href="/about"
					class="rounded-full px-2 py-2 text-xs font-medium text-slate-600 transition-colors hover:bg-slate-100 dark:text-slate-300 dark:hover:bg-white/5 sm:px-3 sm:text-sm sm:text-slate-700 sm:dark:text-slate-200"
				>
					&Uuml;ber
				</a>
				<a
					href="/home"
					class="rounded-full bg-primary px-3 py-2 text-xs font-bold text-white transition-colors hover:bg-primary/90 sm:px-4 sm:text-sm"
				>
					<span class="sm:hidden">Start &rarr;</span>
					<span class="hidden sm:inline">App starten &rarr;</span>
				</a>
			</div>
		</div>
	</nav>

	<main class="mx-auto max-w-5xl px-4 pb-12 sm:px-6 sm:pb-20">
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
