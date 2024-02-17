<script>
	import { dev } from '$app/environment';
</script>

<section
	class="border-t-1 mb-auto flex h-full w-full flex-col gap-6 self-end rounded-br-4xl border border-[#EEEEEE] p-8 sm:rounded-l-4xl lg:px-16"
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
	</div>
</section>

<section
	class="border-t-1 flex w-full flex-col gap-6 rounded-tr-4xl border border-[#EEEEEE] p-8 sm:rounded-r-4xl sm:border-l-0 lg:px-16"
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
			href="/quizzes"
			class="w-full rounded-lg border-2 border-black bg-alphabetGreen p-4 text-center text-xl sm:p-10 sm:text-4xl"
		>
			Quizzes
		</a>
	</div>
	<!-- <div class="flex flex-col gap-2">
		<a
			href="/stats"
			class="w-full rounded-lg border-2 border-black bg-alphabetGreen p-4 text-center text-xl sm:p-10 sm:text-4xl"
		>
			Stats
		</a>
	</div> -->
</section>
