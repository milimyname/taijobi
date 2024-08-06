<script lang="ts">
	import Badge from '$lib/components/ui/badge/badge.svelte';
	import { Button } from '$lib/components/ui/button';
	import * as DrawerDialog from '$lib/components/ui/drawer-dialog';
	import type { RecordModel } from 'pocketbase';
	import * as Card from '$lib/components/ui/card';
	import { openHistory, deleteDrawerDialogOpen, chats } from '$lib/utils/stores';
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
	import * as DropdownMenu from '$lib/components/ui/dropdown-menu';

	let sortedByDate = true;
	let inputValue = '';
	let currentChat: RecordModel | null = $page.params?.slug
		? $chats.find((chat) => chat.id === $page.params.slug)
		: null;

	let newName: string;
	let isChatNameEditable = false;

	function onCloseDrawer() {
		setTimeout(() => ($openHistory = false), 100);
	}

	function onClickOutSideClick(e: PointerEvent | MouseEvent | TouchEvent) {
		// If deleteDrawerDialogOpen is true, don't close the drawer
		if ($deleteDrawerDialogOpen) return;

		onCloseDrawer();
	}

	async function deleteHistory() {
		if (!currentChat) return;

		try {
			await pocketbase.collection('chats').delete(currentChat?.id);

			// filter out the deleted chat
			$chats = $chats.filter((chat) => chat.id !== currentChat?.id);
		} catch (error) {
			console.error('Error deleting search history:', error);
		}

		$openHistory = false;

		setTimeout(() => ($deleteDrawerDialogOpen = false), 150);

		goto('/chat');

		toast.success('Chat deleted successfully! Redirecting to chat page...');
	}

	async function renameChat() {
		if (!currentChat) return;

		try {
			await pocketbase.collection('chats').update(currentChat?.id, {
				name: newName,
			});

			// filter out the deleted chat
			$chats = $chats.map((chat) => {
				if (chat.id === currentChat?.id) chat.name = newName;
				return chat;
			});

			isChatNameEditable = false;
		} catch (error) {
			console.error('Error renaming chat:', error);
		}

		toast.success('Chat renamed successfully! Redirecting to chat page...');
	}

	$: sortedChats = (() => {
		if ($chats.length === 0) return [];

		// Filter the searches based on the input value
		if (inputValue !== '') {
			return $chats.filter((search: RecordModel) =>
				search?.expand?.flashcard?.name.toLowerCase().includes(inputValue.toLowerCase()),
			);
		}

		return sortedByDate
			? $chats.sort(
					(a: RecordModel, b: RecordModel) =>
						Number(new Date(b.created)) - Number(new Date(a.created)),
				)
			: $chats.sort(
					(a: RecordModel, b: RecordModel) =>
						Number(new Date(a.created)) - Number(new Date(b.created)),
				);
	})();

	// Focus the input field when newName is not empty
	$: if (newName) {
		setTimeout(() => {
			const input = document.querySelector('.rename-input') as HTMLInputElement;
			if (input) input.focus();
		}, 100);
	}

	// Reset the newName and isChatNameEditable when the drawer dialog is closed
	$: if (!$openHistory) {
		newName = '';
		isChatNameEditable = false;
	}
</script>

<DeleteDrawerAlertDialog onClick={deleteHistory} />

<DrawerDialog.Root open={$openHistory} onOutsideClick={onClickOutSideClick} onClose={onCloseDrawer}>
	<DrawerDialog.Content
		className={cn('w-full max-h-[90dvh] md:max-w-2xl p-0', $deleteDrawerDialogOpen && 'z-60')}
	>
		<DrawerDialog.Header class="space-y-2 p-5 pb-0 text-left max-md:mb-5">
			<DrawerDialog.Title className="flex py-2 justify-between items-center">
				Chat History
			</DrawerDialog.Title>
			<DrawerDialog.Description className="flex gap-1 sm:gap-2">
				<DrawerDialog.Close asChild let:builder>
					<Button
						builders={[builder]}
						size="icon"
						variant="outline"
						class="w-12 max-w-14"
						on:click={() => {
							currentChat = null;
							onCloseDrawer();
							goto('/chat');
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

				<Input placeholder="Chat Name" bind:value={inputValue} />
			</DrawerDialog.Description>
		</DrawerDialog.Header>
		<ScrollArea class="h-[32rem] w-full">
			<div class="grid gap-2 p-5 pt-0 md:grid-cols-3">
				{#each sortedChats as chat}
					<Card.Root
						class={cn(
							'flex cursor-pointer select-text flex-col justify-between transition-shadow duration-300 ease-linear hover:shadow-md',
							currentChat?.id === chat.id && 'border-2 border-primary',
						)}
					>
						<Card.Header class="relative">
							<Card.Title class="relative flex items-center justify-between gap-2">
								{#if isChatNameEditable && currentChat?.id === chat.id}
									<Input
										class="rename-input w-full md:w-28"
										placeholder="Click Enter to save value"
										bind:value={newName}
									/>
								{:else}
									<span>{chat.name || 'Not given'}</span>
								{/if}

								{#if isChatNameEditable && currentChat?.id === chat.id}
									<Button size="icon" class="size-8" on:click={renameChat}>+</Button>
								{:else}
									<DropdownMenu.Root>
										<DropdownMenu.Trigger>
											<Button
												size="icon"
												variant="none"
												on:click={() => {
													isChatNameEditable = false;
													newName = '';
												}}
											>
												<EllipsisVertical class="size-4 " />
											</Button>
										</DropdownMenu.Trigger>

										<DropdownMenu.Content>
											<DropdownMenu.Group>
												<DropdownMenu.Label>Actions:</DropdownMenu.Label>
												<DropdownMenu.Separator />
												<DropdownMenu.Item
													on:click={() => {
														currentChat = chat;
														$deleteDrawerDialogOpen = true;
													}}
												>
													Delete
												</DropdownMenu.Item>
												<DropdownMenu.Item
													on:click={() => {
														currentChat = chat;
														isChatNameEditable = true;
													}}
												>
													Rename
												</DropdownMenu.Item>
											</DropdownMenu.Group>
										</DropdownMenu.Content>
									</DropdownMenu.Root>
								{/if}
							</Card.Title>
						</Card.Header>
						<Card.Content class="flex flex-wrap gap-1 overflow-auto">
							<Tooltip.Root>
								<Tooltip.Trigger>
									<Badge variant="outline" class="truncate">
										Messages: {chat.messages.length}
									</Badge>
								</Tooltip.Trigger>
								<Tooltip.Content>
									<p>Messages</p>
								</Tooltip.Content>
							</Tooltip.Root>

							<Tooltip.Root>
								<Tooltip.Trigger>
									<Badge variant="outline">
										{new Date(chat?.created).toLocaleDateString()}
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
										currentChat = chat;
										setTimeout(() => {
											$openHistory = false;
											goto(`/chat/${chat.id}`);
										}, 100);
									}}
								>
									See Chat
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
