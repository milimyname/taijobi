<script lang="ts">
	import { page } from '$app/stores';
	import { getHotkeyPrefix } from '$lib/utils';
	import * as DropdownMenu from '$lib/components/ui/dropdown-menu';
	import { CircleHelp } from 'lucide-svelte';
	import { openHistory, openSearch } from '$lib/utils/stores';
	import { goto } from '$app/navigation';
	import { onMount } from 'svelte';

	async function fetchRandomSearch() {
		$openHistory = true;

		try {
			const response = await fetch('/api/search');

			if (!response.ok) throw new Error('Failed to fetch searches');

			const data = await response.json();

			goto('/search/' + data.randomSearch.id);
		} catch (error) {
			console.error(error);
		}
	}

	onMount(() => {
		function handleKeydown(e: KeyboardEvent) {
			if (e.key === 'j' && (e.metaKey || e.ctrlKey)) {
				e.preventDefault();
				fetchRandomSearch();
			}
		}

		document.addEventListener('keydown', handleKeydown);
		return () => {
			document.removeEventListener('keydown', handleKeydown);
		};
	});
</script>

{#if $page.data.isLoggedIn}
	<DropdownMenu.Root>
		<DropdownMenu.Trigger
			class="add-btn fixed bottom-5 left-6 hidden text-sm text-muted-foreground transition-transform lg:block"
		>
			<CircleHelp class="size-5" />
		</DropdownMenu.Trigger>

		<DropdownMenu.Content class="hidden lg:block">
			<DropdownMenu.Item
				class="add-btn flex cursor-pointer justify-between gap-2 text-sm text-muted-foreground"
				on:click={() => ($openSearch = true)}
			>
				<span>Search</span>
				<kbd
					class="pointer-events-none inline-flex h-5 select-none items-center gap-1 rounded border bg-muted px-1.5 font-mono text-[10px] font-medium text-muted-foreground opacity-100"
				>
					<span class="text-xs">{getHotkeyPrefix()}</span>k
				</kbd>
			</DropdownMenu.Item>
			<DropdownMenu.Item
				on:click={fetchRandomSearch}
				class="add-btn flex cursor-pointer justify-between gap-2 text-sm text-muted-foreground"
			>
				<span> Search History </span>
				<kbd
					class="pointer-events-none inline-flex h-5 select-none items-center gap-1 rounded border bg-muted px-1.5 font-mono text-[10px] font-medium text-muted-foreground opacity-100"
				>
					<span class="text-xs">{getHotkeyPrefix()}</span>j
				</kbd>
			</DropdownMenu.Item>
		</DropdownMenu.Content>
	</DropdownMenu.Root>
{/if}
