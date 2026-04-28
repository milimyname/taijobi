<script lang="ts">
	import { page } from '$app/state';
	import Translate from '$lib/icons/Translate.svelte';
	import { error } from '@sveltejs/kit';

	const status = $derived(page.status);
	const message = $derived(page.error?.message ?? 'Unbekannter Fehler');

	const heading = $derived.by(() => {
		if (status === 404) return 'Seite nicht gefunden';
		if (status >= 500) return 'Etwas ist schiefgelaufen';
		if (status === 403) return 'Kein Zugriff';
		return 'Fehler';
	});

	const description = $derived.by(() => {
		if (status === 404) return 'Die Seite, die du suchst, existiert nicht (mehr).';
		if (status >= 500) return 'Ein interger Fehler ist aufgetreten. Versuch es in ein paar Sekunden erneut.';
		return message;
	});
</script>

<div class="flex min-h-[60vh] flex-col items-center justify-center px-6 text-center">
	<div class="mb-6 flex size-20 items-center justify-center rounded-2xl bg-primary/10">
		<Translate class="text-5xl text-primary" />
	</div>

	<p class="text-[11px] font-bold uppercase tracking-widest text-primary">Fehler {status}</p>
	<h1 class="mt-2 text-3xl font-black tracking-tight text-slate-900 dark:text-slate-100">
		{heading}
	</h1>
	<p class="mt-3 max-w-md text-sm text-slate-500 dark:text-slate-400">
		{description}
	</p>

	<div class="mt-8 flex flex-wrap items-center justify-center gap-2">
		<a
			href="/marketplace"
			class="rounded-xl bg-primary px-5 py-2.5 text-sm font-bold text-white shadow-sm transition-colors hover:bg-primary/90"
		>
			Marktplatz
		</a>
		<a
			href="/home"
			class="rounded-xl border border-slate-200 bg-white px-5 py-2.5 text-sm font-medium text-slate-700 shadow-sm transition-colors hover:bg-slate-50 dark:border-white/10 dark:bg-white/5 dark:text-slate-200 dark:hover:bg-white/10"
		>
			App starten
		</a>
	</div>
</div>