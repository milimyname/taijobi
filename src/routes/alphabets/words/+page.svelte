<script lang="ts">
	import { createSwitch, melt } from '@melt-ui/svelte';

	const {
		elements: { root, input }
	} = createSwitch();

	$: console.log($input.checked);
</script>

<form>
	<div class="flex items-center">
		<label class="pr-4 leading-none text-primary" for="airplane-mode" id="airplane-mode-label">
			Airplane mode
		</label>
		<button
			use:melt={$root}
			class="relative h-6 cursor-default rounded-full bg-slate-400 transition-colors data-[state=checked]:bg-primary"
			id="airplane-mode"
			aria-labelledby="airplane-mode-label"
		>
			<span class="thumb block rounded-full bg-white transition" />
		</button>
		<input use:melt={$input} />
	</div>
</form>

<style>
	button {
		--w: 2.75rem;
		--padding: 0.125rem;
		width: var(--w);
	}

	.thumb {
		--size: 1.25rem;
		width: var(--size);
		height: var(--size);
		transform: translateX(var(--padding));
	}

	:global([data-state='checked']) .thumb {
		transform: translateX(calc(var(--w) - var(--size) - var(--padding)));
	}
</style>
