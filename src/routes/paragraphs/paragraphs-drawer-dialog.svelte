<script lang="ts">
	import Badge from '$lib/components/ui/badge/badge.svelte';
	import { Button } from '$lib/components/ui/button';
	import * as DrawerDialog from '$lib/components/ui/drawer-dialog';
	import type { RecordModel } from 'pocketbase';
	import * as Card from '$lib/components/ui/card';
	import { openHistory, deleteDrawerDialogOpen, paragraphs } from '$lib/utils/stores';
	import { ScrollArea } from '$lib/components/ui/scroll-area/index';
	import { goto } from '$app/navigation';
	import { ArrowDown01, ArrowDown10, Plus } from 'lucide-svelte';
	import Input from '$lib/components/ui/input/input.svelte';
	import * as Tooltip from '$lib/components/ui/tooltip';
	import { EllipsisVertical } from 'lucide-svelte';
	import { pocketbase } from '$lib/utils/pocketbase';
	import { cn } from '$lib/utils';
	import DeleteDrawerAlertDialog from '$lib/components/drawer-alert-dialogs/delete-drawer-alert-dialog.svelte';
	import { toast } from 'svelte-sonner';
	import { page } from '$app/stores';

	let sortedByDate = true;
	let inputValue = '';
	let currentParagraphs: RecordModel | null = $page.params?.slug
		? $paragraphs.find((p) => p.id === $page.params.slug)
		: null;

	function onCloseDrawer() {
		setTimeout(() => ($openHistory = false), 100);
	}

	function onClickOutSideClick(e: PointerEvent | MouseEvent | TouchEvent) {
		// If deleteDrawerDialogOpen is true, don't close the drawer
		if ($deleteDrawerDialogOpen) return;

		onCloseDrawer();
	}

	async function deleteHistory() {
		if (!currentParagraphs) return;

		try {
			await pocketbase.collection('paragraphs').delete(currentParagraphs?.id);

			// filter out the deleted paragraph
			$paragraphs = $paragraphs.filter((p) => p.id !== currentParagraphs?.id);
		} catch (error) {
			console.error('Error deleting search history:', error);
		}

		$openHistory = false;

		setTimeout(() => ($deleteDrawerDialogOpen = false), 150);

		goto('/paragraphs');

		toast.success('Paragraph deleted successfully! Redirecting to paragraphs page...');
	}

	$: sortedParagraphs = (() => {
		if ($paragraphs.length === 0) return [];

		// Filter the searches based on the input value
		if (inputValue !== '') {
			return $paragraphs.filter((search: RecordModel) =>
				search?.expand?.flashcard?.name.toLowerCase().includes(inputValue.toLowerCase()),
			);
		}

		return sortedByDate
			? $paragraphs.sort(
					(a: RecordModel, b: RecordModel) =>
						Number(new Date(b.created)) - Number(new Date(a.created)),
				)
			: $paragraphs.sort(
					(a: RecordModel, b: RecordModel) =>
						Number(new Date(a.created)) - Number(new Date(b.created)),
				);
	})();
</script>

<DeleteDrawerAlertDialog onClick={deleteHistory} />

<DrawerDialog.Root open={$openHistory} onOutsideClick={onClickOutSideClick} onClose={onCloseDrawer}>
	<DrawerDialog.Content
		className={cn('w-full max-h-[90dvh] md:max-w-2xl p-0', $deleteDrawerDialogOpen && 'z-60')}
	>
		<DrawerDialog.Header class="space-y-2 p-5 pb-0 text-left max-md:mb-5">
			<DrawerDialog.Title className="flex py-2 justify-between items-center">
				Paragraphs History
			</DrawerDialog.Title>
			<DrawerDialog.Description className="flex gap-1 sm:gap-2">
				<DrawerDialog.Close asChild let:builder>
					<Button
						builders={[builder]}
						size="icon"
						variant="outline"
						class="w-12 max-w-14"
						on:click={() => {
							onCloseDrawer();
							goto('/paragraphs');
						}}
					>
						<Plus class="size-4" />
					</Button>
				</DrawerDialog.Close>
				<Button
					size="icon"
					variant="outline"
					class="w-12 max-w-14"
					on:click={() => (sortedByDate = !sortedByDate)}
				>
					{#if sortedByDate}
						<ArrowDown10 class="size-4" />
					{:else}
						<ArrowDown01 class="size-4" />
					{/if}
				</Button>

				<Input placeholder="Paragraphs Name" bind:value={inputValue} />
			</DrawerDialog.Description>
		</DrawerDialog.Header>
		<ScrollArea class="h-[32rem] w-full">
			<div class="grid gap-2 p-5 pt-0 md:grid-cols-3">
				{#each sortedParagraphs as p}
					<Card.Root
						class={cn(
							'flex cursor-pointer select-text flex-col justify-between transition-shadow duration-300 ease-linear hover:shadow-md',
							currentParagraphs?.id === p.id && 'border-2 border-primary',
						)}
					>
						<Card.Header class="relative">
							<Card.Title class="flex items-center justify-between">
								<span>{p.name || 'Not given'}</span>
								<Button
									size="icon"
									variant="none"
									class="size-fit"
									on:click={() => {
										currentParagraphs = p;
										$deleteDrawerDialogOpen = true;
									}}
								>
									<EllipsisVertical class="size-4 " />
								</Button>
							</Card.Title>
						</Card.Header>
						<Card.Content class="flex flex-wrap gap-1 overflow-auto">
							<Tooltip.Root>
								<Tooltip.Trigger>
									<Badge variant="outline" class="truncate">Files: {p.files.length}</Badge>
								</Tooltip.Trigger>
								<Tooltip.Content>
									<p>Messages</p>
								</Tooltip.Content>
							</Tooltip.Root>

							<Tooltip.Root>
								<Tooltip.Trigger>
									<Badge variant="outline">
										{new Date(p?.created).toLocaleDateString()}
									</Badge>
								</Tooltip.Trigger>
								<Tooltip.Content>
									<p>Search Date</p>
								</Tooltip.Content>
							</Tooltip.Root>
						</Card.Content>
						<Card.Footer>
							<DrawerDialog.Close asChild let:builder>
								<Button
									builders={[builder]}
									variant="outline"
									class="w-full"
									on:click={() => {
										currentParagraphs = p;
										setTimeout(() => {
											$openHistory = false;
											goto(`/paragraphs/${p.id}`);
										}, 100);
									}}
								>
									See Paragraphs
								</Button>
							</DrawerDialog.Close>
						</Card.Footer>
					</Card.Root>
				{/each}
			</div>
		</ScrollArea>
		<DrawerDialog.Footer className="px-5">
			<DrawerDialog.Close asChild let:builder>
				<Button builders={[builder]} variant="outline">Cancel</Button>
			</DrawerDialog.Close>
		</DrawerDialog.Footer>
	</DrawerDialog.Content>
</DrawerDialog.Root>
