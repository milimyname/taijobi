<script lang="ts">
	import Form from '$lib/components/forms/feedback-form.svelte';
	import { Button } from '$lib/components/ui/button';
	import { clickedFeedback, openSearch, feedbackDescription } from '$lib/utils/stores';
	import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import { Search } from 'lucide-svelte';
	import * as DrawerDialog from '$lib/components/ui/drawer-dialog';

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

		onCloseDrawer();
	}

	function onCloseDrawer() {
		setTimeout(() => {
			$clickedFeedback = false;
			$feedbackDescription = '';
		}, 150);
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
				class="fixed left-1/2 top-8 z-10 flex -translate-x-1/2 -translate-y-1/2 justify-center gap-5 px-4 py-2"
			>
				<button class="feedback-btn" on:click={() => ($clickedFeedback = !$clickedFeedback)}>
					{animationText}
				</button>
				<button class="search-btn" on:click|stopPropagation={() => ($openSearch = true)}>
					<Search class="size-4" />
				</button>
			</div>
		</DrawerDialog.Trigger>
	{/if}
	<DrawerDialog.Content
		class="right-0 flex max-w-3xl flex-col max-sm:fixed max-sm:bottom-0 max-sm:left-0 max-sm:max-h-[56dvh]"
	>
		<div class="flex w-full flex-col max-md:overflow-auto md:gap-4">
			<DrawerDialog.Header>
				<DrawerDialog.Title>Leave a feedback or report a bug!</DrawerDialog.Title>
				<DrawerDialog.Description>
					<p class="text-sm">
						You can see them here
						<DrawerDialog.Close>
							<a href="/feedbacks" class="underline" on:click={() => ($clickedFeedback = false)}>
								My Feedbacks
							</a>
						</DrawerDialog.Close>
					</p>
				</DrawerDialog.Description>
			</DrawerDialog.Header>
			<Form {disabled}>
				<DrawerDialog.Close asChild let:builder>
					<Button builders={[builder]} class="w-full" {disabled}>Add</Button>
				</DrawerDialog.Close>
			</Form>
			<DrawerDialog.Footer>
				<DrawerDialog.Close asChild let:builder>
					<Button builders={[builder]} variant="outline">Cancel</Button>
				</DrawerDialog.Close>
			</DrawerDialog.Footer>
		</div>
	</DrawerDialog.Content>
</DrawerDialog.Root>
