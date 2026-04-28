<script lang="ts">
	import AutoStories from '$lib/icons/AutoStories.svelte';
	import CloudOff from '$lib/icons/CloudOff.svelte';
	import Dictionary from '$lib/icons/Dictionary.svelte';
	import Draw from '$lib/icons/Draw.svelte';
	import Inventory2 from '$lib/icons/Inventory2.svelte';
	import Translate from '$lib/icons/Translate.svelte';
</script>

<svelte:head>
	<title>Taijobi — Vokabeln lernen, offline</title>
	<meta name="description" content="Lokale Vokabel-App für Chinesisch, Englisch und Deutsch. Spaced Repetition, Wörterbücher, offline-first. Kein Konto nötig." />
	<meta property="og:type" content="website" />
	<meta property="og:title" content="Taijobi — Vokabeln lernen, offline" />
	<meta property="og:description" content="Lokale Vokabel-App für Chinesisch, Englisch und Deutsch. Spaced Repetition, Wörterbücher, offline-first." />
	<meta property="og:image" content="https://taijobi.com/og/default.png" />
	<meta property="og:url" content="https://taijobi.com/" />
	<meta name="twitter:card" content="summary_large_image" />
	<meta name="twitter:title" content="Taijobi — Vokabeln lernen, offline" />
	<meta name="twitter:description" content="Lokale Vokabel-App für Chinesisch, Englisch und Deutsch. Offline-first." />
	<meta name="twitter:image" content="https://taijobi.com/og/default.png" />
	<link rel="canonical" href="https://taijobi.com/" />
	<style>
		/* Body bg + color come from src/app.css which has html.dark handling.
		   Just set the font here so the landing page doesn't inherit Inter
		   from a stale CSS cache before app.css loads. */
		body { font-family: system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; margin: 0; }
		.jade-gradient { background: linear-gradient(135deg, #195c37 0%, #2d6a4f 100%); }
	</style>
</svelte:head>

<nav class="sticky top-0 z-10 mx-auto flex max-w-4xl items-center justify-between bg-bg-light/90 px-6 py-4 backdrop-blur-xl dark:bg-bg-dark/90">
	<span class="text-xl font-extrabold text-primary">Taijobi</span>
	<div class="flex items-center gap-2 sm:gap-3">
		<a
			href="/marketplace"
			class="rounded-full px-4 py-2 text-sm font-bold text-slate-700 transition-colors hover:bg-slate-100 dark:text-slate-200 dark:hover:bg-white/5"
		>
			Marktplatz
		</a>
		<a
			href="/home"
			class="rounded-full bg-primary px-5 py-2 text-sm font-bold text-white transition-colors hover:bg-primary/90"
		>
			App starten &rarr;
		</a>
	</div>
</nav>

<div class="mx-auto max-w-4xl px-6">
	<!-- Hero -->
	<section class="py-24 text-center">
		<div class="mb-8 inline-flex size-20 items-center justify-center rounded-full bg-primary/10">
			<Translate class="text-5xl text-primary" />
		</div>
		<h1 class="mb-5 text-5xl font-black leading-tight tracking-tight text-slate-900 dark:text-slate-100">
			Vokabeln lernen,<br />auf deinem Ger&auml;t.
		</h1>
		<p class="mx-auto max-w-xl text-lg font-medium leading-relaxed text-slate-500 dark:text-slate-400">
			Chinesisch, Englisch, Deutsch &mdash; alles in einer App.
			Spaced Repetition, W&ouml;rterb&uuml;cher, offline-first.
			Keine Cloud, kein Konto.
		</p>
	</section>

	<!-- Features -->
	<section class="grid grid-cols-1 gap-5 pb-20 md:grid-cols-3">
		<div class="rounded-3xl bg-white p-7 shadow-sm transition-shadow hover:shadow-md dark:bg-white/5 dark:shadow-none dark:ring-1 dark:ring-white/5">
			<div class="mb-4 flex size-14 items-center justify-center rounded-2xl bg-primary/5 dark:bg-primary/10">
				<AutoStories class="text-2xl text-primary" />
			</div>
			<h3 class="mb-2 text-lg font-extrabold text-slate-900 dark:text-slate-100">Spaced Repetition</h3>
			<p class="text-sm leading-relaxed text-slate-500 dark:text-slate-400">
				FSRS-5 Algorithmus passt Intervalle automatisch an.
				Lerne effizient &mdash; wiederhole nur, was du vergisst.
			</p>
		</div>
		<div class="rounded-3xl bg-white p-7 shadow-sm transition-shadow hover:shadow-md dark:bg-white/5 dark:shadow-none dark:ring-1 dark:ring-white/5">
			<div class="mb-4 flex size-14 items-center justify-center rounded-2xl bg-primary/5 dark:bg-primary/10">
				<Dictionary class="text-2xl text-primary" />
			</div>
			<h3 class="mb-2 text-lg font-extrabold text-slate-900 dark:text-slate-100">3 W&ouml;rterb&uuml;cher</h3>
			<p class="text-sm leading-relaxed text-slate-500 dark:text-slate-400">
				CC-CEDICT (124k Chinesisch), Wiktionary Englisch (166k)
				und Deutsch. Nachschlagen und sofort lernen.
			</p>
		</div>
		<div class="rounded-3xl bg-white p-7 shadow-sm transition-shadow hover:shadow-md dark:bg-white/5 dark:shadow-none dark:ring-1 dark:ring-white/5">
			<div class="mb-4 flex size-14 items-center justify-center rounded-2xl bg-primary/5 dark:bg-primary/10">
				<CloudOff class="text-2xl text-primary" />
			</div>
			<h3 class="mb-2 text-lg font-extrabold text-slate-900 dark:text-slate-100">Offline-first</h3>
			<p class="text-sm leading-relaxed text-slate-500 dark:text-slate-400">
				Alles l&auml;uft lokal. SQLite im Browser, OPFS-Speicher.
				Funktioniert ohne Internet. Sync optional.
			</p>
		</div>
	</section>

	<!-- More features -->
	<section class="grid grid-cols-1 gap-5 pb-20 md:grid-cols-2">
		<a
			href="/marketplace"
			class="group rounded-3xl bg-white p-7 shadow-sm transition-shadow hover:shadow-md dark:bg-white/5 dark:shadow-none dark:ring-1 dark:ring-white/5"
		>
			<div class="mb-4 flex size-14 items-center justify-center rounded-2xl bg-primary/5 dark:bg-primary/10">
				<Inventory2 class="text-2xl text-primary" />
			</div>
			<h3 class="mb-2 text-lg font-extrabold text-slate-900 dark:text-slate-100">Pakete-Marktplatz</h3>
			<p class="text-sm leading-relaxed text-slate-500 dark:text-slate-400">
				HSK 1-6, L&oacute;ng neu, Community-Decks und W&ouml;rterb&uuml;cher.
				Importiere auch Anki/Quizlet CSVs.
			</p>
			<p class="mt-3 text-sm font-medium text-primary transition-transform group-hover:translate-x-1 dark:text-accent">
				Pakete durchsuchen &rarr;
			</p>
		</a>
		<div class="rounded-3xl bg-white p-7 shadow-sm transition-shadow hover:shadow-md dark:bg-white/5 dark:shadow-none dark:ring-1 dark:ring-white/5">
			<div class="mb-4 flex size-14 items-center justify-center rounded-2xl bg-primary/5 dark:bg-primary/10">
				<Draw class="text-2xl text-primary" />
			</div>
			<h3 class="mb-2 text-lg font-extrabold text-slate-900 dark:text-slate-100">Strichfolge & Zerlegung</h3>
			<p class="text-sm leading-relaxed text-slate-500 dark:text-slate-400">
				9.500 chinesische Zeichen mit Strichanimation,
				Radikalzerlegung und Etymologie.
			</p>
		</div>
	</section>

	<!-- Tech -->
	<section class="pb-16 text-center">
		<p class="text-xs font-bold uppercase tracking-widest text-slate-400 dark:text-slate-500">
			Powered by Zig + SQLite + Svelte
		</p>
	</section>

	<!-- CTA -->
	<section class="pb-24 text-center">
		<a
			href="/home"
			class="jade-gradient inline-block rounded-full px-10 py-4 text-lg font-extrabold text-white shadow-lg shadow-primary/20 transition-opacity hover:opacity-90"
		>
			Taijobi ausprobieren
		</a>
	</section>
</div>

<!-- Footer -->
<footer class="border-t border-slate-100 px-6 py-8 text-center text-xs font-medium text-slate-400 dark:border-white/5 dark:text-slate-500">
	<p>
		&copy; {new Date().getFullYear()} Taijobi &middot;
		<a href="/changelog" class="font-bold hover:underline">Was ist neu?</a>
		&middot;
		<a href="https://github.com/milimyname/taijobi" class="font-bold hover:underline" target="_blank" rel="noopener noreferrer">
			GitHub
		</a>
	</p>
</footer>
