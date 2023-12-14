<script lang="ts">
	import type { PageData } from './$types';

	export let data: PageData;
</script>

{#if data.posts}
	<article class="prose lg:prose-xl">
		{@html data.posts.html}
	</article>
{/if}
