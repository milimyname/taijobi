<script lang="ts">
	import { posLabel } from '$lib/dict-format';
	import type { DictResult } from '$lib/wasm';

	let { result }: { result: DictResult } = $props();
</script>

<!--
  Structured Wiktionary entry: POS chips, optional etymology, numbered senses
  with tags + example sentences, plus synonyms/antonyms/hypernyms per sense.
  Shared by /dictionary results and /lexicon inline expansion so both render
  the same layout from the same source.
-->
<div class="space-y-3">
	{#each result.groups as group (group.pos)}
		<div>
			<div class="mb-1">
				<span
					class="rounded bg-primary/10 px-1.5 py-0.5 text-[10px] font-bold uppercase tracking-wider text-primary dark:bg-primary/20 dark:text-accent"
				>
					{posLabel(group.pos)}
				</span>
			</div>

			{#if group.etymology}
				<p class="mb-1.5 pl-1 text-[12px] italic leading-snug text-slate-500 dark:text-slate-400">
					<span class="not-italic text-slate-400 dark:text-slate-500">Herkunft:</span>
					{group.etymology}
				</p>
			{/if}

			<ol
				class="space-y-1.5 pl-5 text-[13px] leading-relaxed text-slate-700 dark:text-slate-300"
			>
				{#each group.senses as sense, si (si)}
					<li class="list-decimal marker:text-slate-400 dark:marker:text-slate-500">
						{#if sense.tags.length > 0}
							<span class="mr-1.5">
								{#each sense.tags as tag (tag)}
									<span
										class="mr-1 inline-block rounded bg-slate-100 px-1 py-0.5 text-[10px] font-medium italic text-slate-500 dark:bg-white/10 dark:text-slate-400"
									>
										{tag}
									</span>
								{/each}
							</span>
						{/if}<span>{sense.gloss}</span>

						{#if sense.example}
							<div
								class="mt-0.5 border-l-2 border-slate-200 pl-2 text-[12px] italic text-slate-500 dark:border-white/10 dark:text-slate-400"
							>
								{sense.example}
							</div>
						{/if}

						{#if sense.synonyms.length > 0 || sense.antonyms.length > 0 || sense.hypernyms.length > 0}
							<div class="mt-1 space-y-0.5 text-[12px] leading-snug">
								{#if sense.synonyms.length > 0}
									<div class="text-slate-500 dark:text-slate-400">
										<span class="font-semibold text-primary/70 dark:text-accent/80">Syn.</span>
										{sense.synonyms.join(' · ')}
									</div>
								{/if}
								{#if sense.antonyms.length > 0}
									<div class="text-slate-500 dark:text-slate-400">
										<span class="font-semibold text-rose-500/80 dark:text-rose-400/80">Ant.</span>
										{sense.antonyms.join(' · ')}
									</div>
								{/if}
								{#if sense.hypernyms.length > 0}
									<div class="text-slate-500 dark:text-slate-400">
										<span class="font-semibold text-slate-400 dark:text-slate-500">⊃</span>
										{sense.hypernyms.join(' · ')}
									</div>
								{/if}
							</div>
						{/if}
					</li>
				{/each}
			</ol>
		</div>
	{/each}
</div>
