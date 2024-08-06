<script lang="ts">
	import Badge from '$lib/components/ui/badge/badge.svelte';
	import { Button } from '$lib/components/ui/button';
	import * as DrawerDialog from '$lib/components/ui/drawer-dialog';
	import type { ProgressDataItem } from '$lib/utils/ambient';

	export let isWon: boolean;
	export let correctAnswers: number;
	export let total: number;
	export let startOver: () => void;
	export let progressData: ProgressDataItem[];
	export let loading: boolean;

	function onCloseDrawer() {
		setTimeout(() => (open = false), 100);
	}

	$: open = isWon;
</script>

<DrawerDialog.Root {open} onOutsideClick={onCloseDrawer} onClose={onCloseDrawer}>
	<DrawerDialog.Content className="px-5 space-y-5">
		<DrawerDialog.Header class="p-0 text-left">
			<DrawerDialog.Title>Quiz Result</DrawerDialog.Title>
			<DrawerDialog.Description>
				{#if correctAnswers === total}
					You got all {total} questions correct!
				{:else}
					You got {correctAnswers} out of {total} questions correct.
				{/if}
			</DrawerDialog.Description>
		</DrawerDialog.Header>
		{#if progressData.length > 0}
			<div class="grid grid-cols-2 gap-2">
				{#each progressData as item}
					<span>{item.name}</span>
					{#if item.score === 1}
						<Badge variant="outline" class="my-auto size-fit justify-self-end">Correct</Badge>
					{:else}
						<Badge variant="destructive" class="my-auto size-fit justify-self-end">Incorrect</Badge>
					{/if}
				{/each}
			</div>
		{/if}
		<Button on:click={startOver} class="max-sm:hidden">Start Over</Button>
		<DrawerDialog.Footer className="md:hidden px-0">
			<Button on:click={startOver} {loading} disabled={loading}>Start Over</Button>
			<DrawerDialog.Close asChild let:builder>
				<Button builders={[builder]} variant="outline">Cancel</Button>
			</DrawerDialog.Close>
		</DrawerDialog.Footer>
	</DrawerDialog.Content>
</DrawerDialog.Root>
