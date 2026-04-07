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
	<link rel="preconnect" href="https://fonts.googleapis.com" />
	<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin="anonymous" />
	<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800;900&display=swap" rel="stylesheet" />
	<style>
		body { font-family: 'Inter', system-ui, sans-serif; margin: 0; background: #fefdfb; color: #1a1c1b; }
		.jade-gradient { background: linear-gradient(135deg, #195c37 0%, #2d6a4f 100%); }
	</style>
</svelte:head>

<nav class="sticky top-0 z-10 bg-[#fefdfb]/90 backdrop-blur-xl px-6 py-4 flex items-center justify-between max-w-4xl mx-auto">
	<span class="text-xl font-extrabold text-[#195c37]">Taijobi</span>
	<a
		href="/home"
		class="text-sm font-bold text-white bg-[#195c37] px-5 py-2 rounded-full hover:bg-[#195c37]/90 transition-colors"
	>
		App starten &rarr;
	</a>
</nav>

<div class="max-w-4xl mx-auto px-6">
	<!-- Hero -->
	<section class="py-24 text-center">
		<div class="inline-flex items-center justify-center w-20 h-20 rounded-full bg-[#195c37]/10 mb-8">
			<Translate class="text-[#195c37] text-5xl" />
		</div>
		<h1 class="text-5xl font-black text-slate-900 mb-5 tracking-tight leading-tight">
			Vokabeln lernen,<br />auf deinem Ger&auml;t.
		</h1>
		<p class="text-lg text-slate-500 max-w-xl mx-auto leading-relaxed font-medium">
			Chinesisch, Englisch, Deutsch &mdash; alles in einer App.
			Spaced Repetition, W&ouml;rterb&uuml;cher, offline-first.
			Keine Cloud, kein Konto.
		</p>
	</section>

	<!-- Features -->
	<section class="grid grid-cols-1 md:grid-cols-3 gap-5 pb-20">
		<div class="bg-white rounded-3xl p-7 shadow-sm hover:shadow-md transition-shadow">
			<div class="w-14 h-14 rounded-2xl bg-[#195c37]/5 flex items-center justify-center mb-4">
				<AutoStories class="text-2xl text-[#195c37]" />
			</div>
			<h3 class="font-extrabold text-slate-900 mb-2 text-lg">Spaced Repetition</h3>
			<p class="text-sm text-slate-500 leading-relaxed">
				FSRS-5 Algorithmus passt Intervalle automatisch an.
				Lerne effizient &mdash; wiederhole nur, was du vergisst.
			</p>
		</div>
		<div class="bg-white rounded-3xl p-7 shadow-sm hover:shadow-md transition-shadow">
			<div class="w-14 h-14 rounded-2xl bg-[#195c37]/5 flex items-center justify-center mb-4">
				<Dictionary class="text-2xl text-[#195c37]" />
			</div>
			<h3 class="font-extrabold text-slate-900 mb-2 text-lg">3 W&ouml;rterb&uuml;cher</h3>
			<p class="text-sm text-slate-500 leading-relaxed">
				CC-CEDICT (124k Chinesisch), Wiktionary Englisch (166k)
				und Deutsch. Nachschlagen und sofort lernen.
			</p>
		</div>
		<div class="bg-white rounded-3xl p-7 shadow-sm hover:shadow-md transition-shadow">
			<div class="w-14 h-14 rounded-2xl bg-[#195c37]/5 flex items-center justify-center mb-4">
				<CloudOff class="text-2xl text-[#195c37]" />
			</div>
			<h3 class="font-extrabold text-slate-900 mb-2 text-lg">Offline-first</h3>
			<p class="text-sm text-slate-500 leading-relaxed">
				Alles l&auml;uft lokal. SQLite im Browser, OPFS-Speicher.
				Funktioniert ohne Internet. Sync optional.
			</p>
		</div>
	</section>

	<!-- More features -->
	<section class="grid grid-cols-1 md:grid-cols-2 gap-5 pb-20">
		<div class="bg-white rounded-3xl p-7 shadow-sm hover:shadow-md transition-shadow">
			<div class="w-14 h-14 rounded-2xl bg-[#195c37]/5 flex items-center justify-center mb-4">
				<Inventory2 class="text-2xl text-[#195c37]" />
			</div>
			<h3 class="font-extrabold text-slate-900 mb-2 text-lg">Content Packs</h3>
			<p class="text-sm text-slate-500 leading-relaxed">
				HSK 1-6, L&oacute;ng neu und mehr. Importiere Anki/Quizlet CSVs.
				Strukturiertes Lernen mit Lektionen.
			</p>
		</div>
		<div class="bg-white rounded-3xl p-7 shadow-sm hover:shadow-md transition-shadow">
			<div class="w-14 h-14 rounded-2xl bg-[#195c37]/5 flex items-center justify-center mb-4">
				<Draw class="text-2xl text-[#195c37]" />
			</div>
			<h3 class="font-extrabold text-slate-900 mb-2 text-lg">Strichfolge & Zerlegung</h3>
			<p class="text-sm text-slate-500 leading-relaxed">
				9.500 chinesische Zeichen mit Strichanimation,
				Radikalzerlegung und Etymologie.
			</p>
		</div>
	</section>

	<!-- Tech -->
	<section class="text-center pb-16">
		<p class="text-xs text-slate-400 tracking-widest uppercase font-bold">
			Powered by Zig + SQLite + Svelte
		</p>
	</section>

	<!-- CTA -->
	<section class="text-center pb-24">
		<a
			href="/home"
			class="inline-block jade-gradient text-white font-extrabold text-lg px-10 py-4 rounded-full hover:opacity-90 transition-opacity shadow-lg shadow-[#195c37]/20"
		>
			Taijobi ausprobieren
		</a>
	</section>
</div>

<!-- Footer -->
<footer class="border-t border-slate-100 py-8 px-6 text-center text-xs text-slate-400 font-medium">
	<p>
		&copy; {new Date().getFullYear()} Taijobi &middot;
		<a href="/changelog" class="hover:underline font-bold">Was ist neu?</a>
		&middot;
		<a href="https://github.com/milimyname/taijobi" class="hover:underline font-bold" target="_blank" rel="noopener noreferrer">
			GitHub
		</a>
	</p>
</footer>
