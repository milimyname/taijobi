<script lang="ts">
	import * as Dialog from '$lib/components/ui/dialog';
	import * as Drawer from '$lib/components/ui/drawer';
	import { Button } from '$lib/components/ui/button';
	import { isDesktop } from '$lib/utils';

	export let isWon: boolean;
	export let correctAnswers: number;
	export let total: number;
	export let startOver: () => void;

	$: open = isWon;
</script>

{#if $isDesktop}
	<Dialog.Root bind:open>
		<Dialog.Content class="z-[100] sm:max-w-[425px]">
			<Dialog.Header>
				<Dialog.Title>Quiz Result</Dialog.Title>
				<Dialog.Description>
					{#if correctAnswers === total}
						You got all {total} questions correct!
					{:else}
						You got {correctAnswers} out of {total} questions correct.
					{/if}
				</Dialog.Description>
			</Dialog.Header>
			<Button on:click={startOver}>Start Over</Button>
		</Dialog.Content>
	</Dialog.Root>
{:else}
	<Drawer.Root {open}>
		<Drawer.Portal>
			<Drawer.Content class="h-fit">
				<Drawer.Header class="text-left">
					<Drawer.Title class="w-full">Quiz Results</Drawer.Title>
					<Drawer.Description>
						{#if correctAnswers === total}
							You got all {total} questions correct!
						{:else}
							You got {correctAnswers} out of {total} questions correct.
						{/if}
					</Drawer.Description>
				</Drawer.Header>

				<Drawer.Footer class="h-fit">
					<Button on:click={startOver}>Start Over</Button>

					<Drawer.Close asChild let:builder>
						<Button builders={[builder]} variant="outline">Cancel</Button>
					</Drawer.Close>
				</Drawer.Footer>
			</Drawer.Content>
		</Drawer.Portal>
	</Drawer.Root>
{/if}
