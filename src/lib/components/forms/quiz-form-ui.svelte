<script lang="ts">
	import { clickedQuizForm, selectedQuizItems } from '$lib/utils/stores';
	import { Button } from '$lib/components/ui/button';
	import Form from '$lib/components/forms/quiz-form.svelte';
	import { type QuizSchema } from '$lib/utils/zodSchema';
	import { type SuperForm, type Infer } from 'sveltekit-superforms';
	import * as DrawerDialog from '$lib/components/ui/drawer-dialog';

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

<DrawerDialog.Root bind:open={$clickedQuizForm} {onOutsideClick}>
	<DrawerDialog.Overlay class="fixed inset-0 bg-black bg-opacity-30" />
	<DrawerDialog.Content class="z-[100] sm:max-w-[425px]">
		<DrawerDialog.Header>
			<DrawerDialog.Title>Create a quiz</DrawerDialog.Title>
		</DrawerDialog.Header>
		<Form {form}>
			<div slot="add" class="space-y-2">
				<DrawerDialog.Close asChild let:builder>
					<Button builders={[builder]} class="w-full" {disabled}>Add</Button>
				</DrawerDialog.Close>
				<DrawerDialog.Footer className="md:hidden p-0">
					<DrawerDialog.Close asChild let:builder>
						<Button
							builders={[builder]}
							variant="outline"
							on:click={(e) => {
								e.preventDefault();
								onOutsideClick(e);
							}}
						>
							Cancel
						</Button>
					</DrawerDialog.Close>
				</DrawerDialog.Footer>
			</div>
		</Form>
	</DrawerDialog.Content>
</DrawerDialog.Root>
