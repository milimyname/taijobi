<script lang="ts">
	import { innerHeightStore, innerWidthStore } from '$lib/utils/stores';
	import { getFlashcardHeight, getFlashcardWidth } from '$lib/utils';
</script>

<div
	style={`height: ${getFlashcardHeight($innerWidthStore, $innerHeightStore)}px; width: ${getFlashcardWidth($innerWidthStore)}px`}
	class="flex animate-pulse justify-center"
>
	<div
		class="flex h-full w-full items-center justify-center rounded-xl border shadow-sm bg-dotted-spacing-8 bg-dotted-gray-200"
	>
		<span class="vertical text-5xl sm:text-7xl">ローディング</span>
	</div>
</div>
