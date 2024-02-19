<script lang="ts">
	import { innerHeightStore, innerWidthStore } from '$lib/utils/stores';
	import { getFlashcardHeight, getFlashcardWidth } from '$lib/utils';
</script>

<div
	style={`height: ${getFlashcardHeight($innerWidthStore, $innerHeightStore)}px; width: ${getFlashcardWidth($innerWidthStore)}px`}
	class="rounded-xl border p-4 shadow"
>
	<div class="grid h-full w-full animate-pulse grid-cols-2 grid-rows-4 gap-4">
		<div class="row-span-2 rounded-lg bg-slate-100"></div>
		<div class="row-span-2 rounded-lg bg-slate-100"></div>
		<div class="row-span-2 rounded-lg bg-slate-100"></div>
		<div class="row-span-2 rounded-lg bg-slate-100"></div>
	</div>
</div>
