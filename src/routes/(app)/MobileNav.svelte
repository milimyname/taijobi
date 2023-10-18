<script lang="ts">
	import { fly } from 'svelte/transition';
	import { sineIn } from 'svelte/easing';
	import { showAppNav, showNav } from '$lib/utils/stores';
	import { clickOutside } from '$lib/utils/clickOutside';
	import { icons } from '$lib/utils/icons';
	import { navItems } from '$lib/utils/constants';
</script>

{#if $showNav}
	<div
		use:clickOutside
		on:outsideclick={() => {
			$showNav = false;
			$showAppNav = false;
		}}
		class="fixed bottom-20 z-30 w-full p-5"
		transition:fly={{
			delay: 0,
			duration: 500,
			opacity: 0,
			y: 50,
			easing: sineIn
		}}
	>
		{#each navItems.slice(0, 3) as item}
			<div
				class="{item.mb} {item.height} {item.borderColor} w-full rounded-4xl border-4 bg-white shadow-xl"
			>
				<a
					href={item.url}
					class="flex justify-between p-4"
					on:click={() => {
						$showAppNav = false;
						$showNav = false;
					}}
				>
					{@html icons[item.icon]}
					<h4 class="text-xl font-medium">{item.label}</h4>
				</a>
			</div>
		{/each}
	</div>
{:else if $showAppNav}
	<div
		use:clickOutside
		on:outsideclick={() => {
			$showNav = false;
			$showAppNav = false;
		}}
		class="fixed bottom-20 z-30 w-full p-5"
		transition:fly={{
			delay: 0,
			duration: 500,
			opacity: 0,
			y: 50,
			easing: sineIn
		}}
	>
		{#each navItems.slice(3, 6) as item}
			<div
				class="{item.mb} {item.height} {item.borderColor} w-full rounded-4xl border-4 bg-white shadow-xl"
			>
				<a
					href={item.url}
					class="flex justify-between p-4"
					on:click={() => {
						$showAppNav = false;
						$showNav = false;
					}}
				>
					{@html icons[item.icon]}
					<h4 class="text-xl font-medium">{item.label}</h4>
				</a>
			</div>
		{/each}
	</div>
{/if}
