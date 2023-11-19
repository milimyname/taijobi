<script lang="ts">
	import { spring } from 'svelte/motion';

	export let value: number;
	export let index: number;
	export let totalCount: number;

	const colorStart = `hsl(360, 81.7%, 87.8%)`; // $red6
	const colorEnd = `hsl(358, 65.0%, 48.7%)`; // $red11

	// Calculate the spring values for x, y, rotation, and scale based on index
	const x = spring(2 - index * 30, { stiffness: 0.1, damping: 0.5 });
	const y = spring(index * 5, { stiffness: 0.1, damping: 0.5 });
	const rotateZ = spring(360 - index * 5, { stiffness: 0.1, damping: 0.5 });
	const scale = spring(1 - (totalCount - index - 1) * 0.05, { stiffness: 0.1, damping: 0.5 });

	let isDragging = false;
	let startX: number, startY: number, initialX: number, initialY: number;
	let cardElement;

	function onDragStart(event: { clientX: number; clientY: number; preventDefault: () => void; }) {
		isDragging = true;
		startX = event.clientX;
		startY = event.clientY;
		initialX = $x;
		initialY = $y;
		event.preventDefault(); // Prevents text selection, etc.
	}

	function onDrag(event: { clientX: number; clientY: number; }) {
		if (!isDragging) return;
		const dx = event.clientX - startX;
		const dy = event.clientY - startY;
		x.set(initialX + dx);
		y.set(initialY + dy);
	}

	function onDragEnd() {
		isDragging = false;
		// Optionally snap back to original position or trigger some action
		x.set(2 - index * 30);
		y.set(index * 5);
	}

	// Add window event listeners to handle the drag
	// Note: Ideally, you would clean up these listeners when the component is destroyed
	if (typeof window !== 'undefined') {
		window.addEventListener('mousemove', onDrag);
		window.addEventListener('mouseup', onDragEnd);
	}

	// Reactive statements to update spring values when index changes
	$: x.set(2 - index * 30);
	$: y.set(index * 5);
	$: rotateZ.set(360 - index * 5);
	$: scale.set(1 - (totalCount - index - 1) * 0.05);
</script>

<button
	bind:this={cardElement}
	on:mousedown={onDragStart}
	on:click
	style="transform: translate({$x}px, {$y}px) rotateZ({$rotateZ}deg) scale({$scale}); background: linear-gradient(-45deg, rgb(154, 33, 37), rgb(244, 143, 143)); boxShadow: 0px 4px 4px rgba(0, 0, 0, 0.25)"
	class="absolute flex h-60 w-40 items-center justify-center rounded-xl  text-6xl font-bold "
>
	<span>{value}</span>
</button>

