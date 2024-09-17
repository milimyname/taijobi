<script>
	import { dev } from '$app/environment';
	import { goto } from '$app/navigation';
	import { page } from '$app/stores';
	import { Button } from '$lib/components/ui/button';
	import { toast } from 'svelte-sonner';
</script>

<section
	class="border-t-1 mb-auto flex h-full w-full flex-col gap-6 self-end rounded-t-4xl border border-[#EEEEEE] p-8 sm:h-auto lg:rounded-l-4xl lg:rounded-r-none lg:px-16"
>
	<h2 class="text-lg font-bold sm:text-2xl">Alphabets</h2>
	<div class="flex flex-col gap-2">
		<a
			href="/alphabets/hiragana"
			class="w-full rounded-lg border-2 border-black bg-alphabetGreen p-4 text-center text-xl sm:p-10 sm:text-4xl"
		>
			ひらがな
		</a>
		<a
			href="/alphabets/katakana"
			class="w-full rounded-lg border-2 border-black bg-alphabetGreen p-4 text-center text-xl sm:p-10 sm:text-4xl"
		>
			カタカナ
		</a>
		<a
			href="/alphabets/kanji"
			class="w-full rounded-lg border-2 border-black bg-alphabetGreen p-4 text-center text-xl sm:p-10 sm:text-4xl"
		>
			漢字
		</a>

		{#if dev}
			<a
				href="/test"
				class="w-full rounded-lg border-2 border-black bg-alphabetGreen p-4 text-center text-xl sm:p-10 sm:text-4xl"
			>
				Test
			</a>
		{/if}

		{#if $page.data.isLoggedIn}
			<a
				href="/chat"
				class="w-full rounded-lg border-2 border-black bg-alphabetGreen p-4 text-center text-xl sm:p-10 sm:text-4xl"
			>
				Chat
			</a>
		{:else}
			<Button
				variant="none"
				on:click={() => {
					toast('Please login to access this feature.', {
						action: {
							label: 'Login',
							onClick: () => {
								goto('/login');
							},
						},
					});
					return;
				}}
				class="w-full rounded-lg border-2 border-black bg-alphabetGreen py-8 text-center text-xl font-normal sm:text-4xl md:p-14"
			>
				Chat
			</Button>
		{/if}
	</div>
</section>

<section
	class="flex w-full flex-col gap-6 rounded-b-4xl border border-t border-[#EEEEEE] px-8 pb-20 pt-14 lg:rounded-b-none lg:rounded-r-4xl lg:border-l-0 lg:px-16"
>
	<h2 class="text-lg font-bold sm:text-2xl">Studying</h2>
	<div class="flex flex-col gap-2">
		<a
			href="/flashcards"
			class="w-full rounded-lg border-2 border-black bg-alphabetGreen p-4 text-center text-xl sm:p-10 sm:text-4xl"
		>
			Flashcards
		</a>
	</div>
	<div class="flex flex-col gap-2">
		<a
			href="/games"
			class="w-full rounded-lg border-2 border-black bg-alphabetGreen p-4 text-center text-xl sm:p-10 sm:text-4xl"
		>
			Games
		</a>
	</div>
	<div class="flex flex-col gap-2">
		{#if $page.data.isLoggedIn}
			<a
				href="/paragraphs"
				class="w-full rounded-lg border-2 border-black bg-alphabetGreen p-4 text-center text-xl sm:p-10 sm:text-4xl"
			>
				Paragraphs
			</a>
		{:else}
			<Button
				variant="none"
				on:click={() => {
					toast('Please login to access this feature.', {
						action: {
							label: 'Login',
							onClick: () => {
								goto('/login');
							},
						},
					});
					return;
				}}
				class="w-full rounded-lg border-2 border-black bg-alphabetGreen py-8 text-center text-xl font-normal sm:text-4xl md:p-14"
			>
				Paragraphs
			</Button>
		{/if}
	</div>
</section>
