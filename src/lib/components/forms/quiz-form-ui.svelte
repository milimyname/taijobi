<script lang="ts">
	import { clickedQuizForm, selectedQuizItems, selectQuizItemsForm } from '$lib/utils/stores';
	import { Button } from '$lib/components/ui/button';
	import Form from '$lib/components/forms/quiz-form.svelte';
	import { type QuizSchema } from '$lib/utils/zodSchema';
	import { type SuperForm, type Infer } from 'sveltekit-superforms';
	import * as DrawerDialog from '$lib/components/ui/drawer-dialog';
	import QuizItemsUi from './quiz-items-ui.svelte';

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

		// If se is true, don't close the drawer
		if ($selectQuizItemsForm) return;

		onClose();
	};

	$: disabled = $formData.name === '';
</script>

<QuizItemsUi {form} />

<DrawerDialog.Root bind:open={$clickedQuizForm} {onOutsideClick}>
	<DrawerDialog.Content class="h-fit max-h-fit">
		<DrawerDialog.Header>
			<DrawerDialog.Title>Create a quiz</DrawerDialog.Title>
		</DrawerDialog.Header>
		<Form {form}>
			<div slot="add" class="space-y-2">
				<DrawerDialog.Footer className="p-0 max-md:pb-5 md:block">
					<DrawerDialog.Close asChild let:builder>
						<Button builders={[builder]} class="w-full" {disabled}>Add</Button>
					</DrawerDialog.Close>
					<DrawerDialog.Close asChild let:builder>
						<Button
							builders={[builder]}
							variant="outline"
							on:click={(e) => {
								e.preventDefault();
								onOutsideClick(e);
							}}
							class="md:hidden"
						>
							Cancel
						</Button>
					</DrawerDialog.Close>
				</DrawerDialog.Footer>
			</div>
		</Form>
	</DrawerDialog.Content>
</DrawerDialog.Root>
