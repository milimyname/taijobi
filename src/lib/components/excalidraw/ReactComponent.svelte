<script lang="ts">
	import * as React from 'react';
	import { createRoot } from 'react-dom/client';
	import { afterUpdate, onDestroy, onMount } from 'svelte';

	let container: HTMLElement;

	let root: ReturnType<typeof createRoot>;
	onMount(() => {
		root = createRoot(container);
		const { this: component, children, ...props } = $$props;

		root.render(React.createElement(component, props, children));
	});

	onDestroy(() => {
		root.unmount();
	});
</script>

<div class="reactComponent" bind:this={container} />

<style>
	.reactComponent {
		/* TODO fix height */
		height: 25rem;
		width: 100%;
	}

	:global(.mobile-misc-tools-container label[title='Library']) {
		display: none !important;
	}

	:global(.mobile-misc-tools-container label[title='Keep selected tool active after drawing — Q']) {
		display: none !important;
	}

	:global(.App-toolbar-content .dropdown-menu-button) {
		visibility: hidden !important;
		opacity: 0 !important;
		pointer-events: none !important;
	}

	:global(.App-bottom-bar .Island) {
		background: none !important;
		box-shadow: none !important;
	}

	:global(.Stack label[title='Rectangle — R or 2']) {
		display: none !important;
	}
	:global(.Stack label[title='Hand (panning tool) — H']) {
		display: block;
	}

	:global(.Stack label[title='Diamond — D or 3']) {
		display: none !important;
	}

	:global(.Stack label[title='Ellipse — O or 4']) {
		display: none !important;
	}

	:global(.Stack label[title='Line — L or 6']) {
		display: none !important;
	}
	:global(.Stack label[title='Arrow — A or 5']) {
		display: none !important;
	}
	:global(.Stack label[title='Insert image — 9']) {
		display: none !important;
	}
	:global(.Stack label[title='Text — T or 8']) {
		display: none !important;
	}
	:global(.App-toolbar__divider) {
		display: none !important;
	}
	:global(.Stack button) {
		display: none !important;
	}
	:global(.layer-ui__wrapper__top-right) {
		display: none !important;
	}
	:global(.layer-ui__wrapper__footer-right) {
		display: none !important;
	}
</style>
