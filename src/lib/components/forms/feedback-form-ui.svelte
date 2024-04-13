<script lang="ts">
	import * as Dialog from '$lib/components/ui/dialog';
	import * as Drawer from '$lib/components/ui/drawer';
	import Form from '$lib/components/forms/feedback-form.svelte';
	import { Button } from '$lib/components/ui/button';
	import { clickedFeedback, openSearch } from '$lib/utils/stores';
	import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import { isDesktop } from '$lib/utils';
	import { Search } from 'lucide-svelte';

	let animationText = '';
	let isReversing = false;

	async function performAnimation() {
		const texts = ['😊', '🐞'];

		// Calculate the delay based on the character count, correctly handling surrogate pairs
		const delay = 2000 / (Array.from(texts[isReversing ? 0 : 1]).length - 1);

		// Convert the text to an array of characters, correctly handling emojis and surrogate pairs
		const characters = Array.from(texts[isReversing ? 0 : 1]);

		for (let i = 0; i < characters.length; i++) {
			// Use the array of characters to build up the animationText
			animationText = characters.slice(0, i + 1).join('');
			await new Promise((resolve) => setTimeout(resolve, delay));
		}

		if (isReversing) isReversing = false;
		else isReversing = true;

		// Use setTimeout to continue or reverse the animation, ensuring proper handling of the asynchronous call
		setTimeout(performAnimation, 2000);
	}

	// You would need to define isReversing and possibly other missing variables or logic outside this snippet.
	function onOutsideClickDrawer(e: MouseEvent | TouchEvent | PointerEvent) {
		//  If the user clicks on the leave button, don't move the card

		if ($page.url.pathname.includes('flashcards') && (e.target as Element).closest('.feedback-btn'))
			return;

		if ($page.url.pathname.slice(1) === 'flashcards') $clickedFeedback = false;
	}

	onMount(() => performAnimation());

	$: hide =
		$page.url.pathname.slice(1) === 'login' ||
		$page.url.pathname.slice(1) === 'signup' ||
		$page.url.pathname.slice(1) === 'admin' ||
		$page.url.pathname.startsWith('/test') ||
		!$page.data.isLoggedIn;

	$: if ($openSearch) $openSearch = true;
</script>

{#if $isDesktop}
	<Dialog.Root bind:open={$clickedFeedback}>
		{#if !hide}
			<Dialog.Trigger asChild let:builder>
				<Button
					variant="none"
					builders={[builder]}
					class="feedback-btn absolute left-1/2 top-12 z-20 -translate-x-1/2 -translate-y-1/2 border-none px-4 py-2"
				>
					{animationText}
				</Button>
				<button
					on:click|stopPropagation={() => ($openSearch = true)}
					class="search-btn absolute left-1/2 top-12 z-20 ml-10 h-10 -translate-x-1/2 -translate-y-1/2 rounded-md border-none px-4 py-2"
				>
					<Search class="size-4" />
				</button>
			</Dialog.Trigger>
		{/if}
		<Dialog.Overlay class="fixed inset-0 bg-black bg-opacity-30" />
		<Dialog.Content class="z-[100] sm:max-w-[425px]">
			<Dialog.Header>
				<Dialog.Title>Leave a feedback or report a bug!</Dialog.Title>
				<Dialog.Description>
					<p class="text-sm">
						You can see them here
						<a href="/feedbacks" on:click={() => ($clickedFeedback = false)} class="underline">
							My Feedbacks
						</a>
					</p>
				</Dialog.Description>
			</Dialog.Header>
			<Form />
		</Dialog.Content>
	</Dialog.Root>
{:else}
	<Drawer.Root open={$clickedFeedback} onOutsideClick={onOutsideClickDrawer}>
		{#if !hide}
			<Dialog.Trigger asChild let:builder>
				<Button
					variant="none"
					builders={[builder]}
					class="feedback-btn absolute left-1/2 top-10 z-20 -translate-x-1/2 -translate-y-1/2 bg-white px-4 py-2"
				>
					{animationText}
				</Button>
				<button
					on:click|stopPropagation={() => ($openSearch = true)}
					class="search-btn absolute left-1/2 top-10 z-20 ml-10 h-10 -translate-x-1/2 -translate-y-1/2 rounded-md bg-white px-4 py-2"
				>
					<Search class="size-4" />
				</button>
			</Dialog.Trigger>
		{/if}
		<Drawer.Portal>
			<Drawer.Content>
				<Drawer.Header class="text-left">
					<Drawer.Title>Leave a feedback or report a bug!</Drawer.Title>
					<Drawer.Description>
						<p class="text-sm">
							You can see them here
							<a href="/feedbacks" on:click={() => ($clickedFeedback = false)} class="underline">
								My Feedbacks
							</a>
						</p>
					</Drawer.Description>
				</Drawer.Header>
				<Form />

				<Drawer.Footer>
					<Drawer.Close asChild let:builder>
						<Button builders={[builder]} variant="outline">Cancel</Button>
					</Drawer.Close>
				</Drawer.Footer>
			</Drawer.Content>
		</Drawer.Portal>
	</Drawer.Root>
{/if}
