<script lang="ts">
	import Form from '$lib/components/forms/feedback-form.svelte';
	import { Button } from '$lib/components/ui/button';
	import { clickedFeedback, openSearch, feedbackDescription } from '$lib/utils/stores';
	import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import { Search } from 'lucide-svelte';
	import * as DrawerDialog from '$lib/components/ui/drawer-dialog';
	import { goto } from '$app/navigation';

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

		setTimeout(() => {
			$clickedFeedback = false;
			$feedbackDescription = '';
		}, 100);
	}

	function onCloseDrawer() {
		setTimeout(() => {
			$clickedFeedback = false;
			$feedbackDescription = '';
		}, 100);
	}

	onMount(() => performAnimation());

	$: hide =
		$page.url.pathname.slice(1) === 'login' ||
		$page.url.pathname.slice(1) === 'signup' ||
		$page.url.pathname.slice(1) === 'admin' ||
		$page.url.pathname.startsWith('/test') ||
		!$page.data.isLoggedIn;

	$: if ($openSearch) $openSearch = true;

	$: disabled = $feedbackDescription === '';
</script>

<DrawerDialog.Root
	open={$clickedFeedback}
	onOutsideClick={onOutsideClickDrawer}
	onClose={onCloseDrawer}
>
	{#if !hide}
		<DrawerDialog.Trigger asChild>
			<div
				class="feedback-btn absolute left-1/2 top-8 z-10 flex -translate-x-1/2 -translate-y-1/2 justify-center gap-5 px-4 py-2"
			>
				<button on:click={() => ($clickedFeedback = !$clickedFeedback)}>
					{animationText}
				</button>
				<button on:click|stopPropagation={() => ($openSearch = true)} class="search-btn">
					<Search class="size-4" />
				</button>
			</div>
		</DrawerDialog.Trigger>
	{/if}
	<DrawerDialog.Content
		class="max-md:fixed max-md:bottom-0 max-md:left-0 max-md:right-0 max-md:flex max-md:h-full max-md:max-h-[96%] max-md:flex-col"
	>
		<DrawerDialog.Header>
			<DrawerDialog.Title>Leave a feedback or report a bug!</DrawerDialog.Title>
			<DrawerDialog.Description>
				<p class="text-sm">
					You can see them here
					<DrawerDialog.Close>
						<Button href="/feedbacks" variant="link" class="p-0 underline">My Feedbacks</Button>
					</DrawerDialog.Close>
				</p>
			</DrawerDialog.Description>
		</DrawerDialog.Header>
		<Form {disabled}>
			{#if !disabled}
				<DrawerDialog.Close asChild let:builder>
					<Button builders={[builder]} class="w-full" {disabled}>Add</Button>
				</DrawerDialog.Close>
			{/if}
		</Form>
		<DrawerDialog.Footer>
			<DrawerDialog.Close asChild let:builder>
				<Button builders={[builder]} variant="outline">Cancel</Button>
			</DrawerDialog.Close>
		</DrawerDialog.Footer>
	</DrawerDialog.Content>
</DrawerDialog.Root>
