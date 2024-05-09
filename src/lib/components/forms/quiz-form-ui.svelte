<script lang="ts">
	import { clickedQuizForm, selectedQuizItems } from '$lib/utils/stores';
	import * as Dialog from '$lib/components/ui/dialog';
	import * as Drawer from '$lib/components/ui/drawer';
	import { Button } from '$lib/components/ui/button';
	import Form from '$lib/components/forms/quiz-form.svelte';
	import { isDesktop } from '$lib/utils';
	import { type QuizSchema } from '$lib/utils/zodSchema';
	import { type SuperForm, type Infer } from 'sveltekit-superforms';

	export let form: SuperForm<Infer<QuizSchema>>;

	const { form: formData } = form;

	function onClose() {
		setTimeout(() => {
			$clickedQuizForm = false;
			$selectedQuizItems = [];
			form.reset();
		}, 100);
	}

	const onOutsideClick = (e: MouseEvent | TouchEvent) => {
		// return if it clicked on the form
		if (e.target instanceof HTMLElement && e.target.closest('.select-quiz-data')) return;

		onClose();
	};

	$: disabled = $formData.name === '';
</script>

{#if $isDesktop}
	<Dialog.Root bind:open={$clickedQuizForm} {onOutsideClick}>
		<Dialog.Overlay class="fixed inset-0 bg-black bg-opacity-30" />
		<Dialog.Content class="z-[100] sm:max-w-[425px]">
			<Dialog.Header>
				<Dialog.Title>Create a quiz</Dialog.Title>
			</Dialog.Header>
			<Form {form}>
				<div slot="add">
					<Button formaction="?/add" class="w-full" {disabled}>Add</Button>
				</div>
			</Form>
		</Dialog.Content>
	</Dialog.Root>
{:else}
	<Drawer.Root {onClose} open={$clickedQuizForm} {onOutsideClick}>
		<Drawer.Portal>
			<Drawer.Content>
				<Drawer.Header class="text-left">
					<Drawer.Title>Create a quiz</Drawer.Title>
				</Drawer.Header>
				<Form {form}>
					<div slot="add">
						<Drawer.Close asChild let:builder>
							<Button builders={[builder]} class="w-full" {disabled}>Add</Button>
						</Drawer.Close>
					</div>
				</Form>
				<Drawer.Footer>
					<Drawer.Close asChild let:builder>
						<Button builders={[builder]} variant="outline">Cancel</Button>
					</Drawer.Close>
				</Drawer.Footer>
			</Drawer.Content>
		</Drawer.Portal>
	</Drawer.Root>
{/if}
