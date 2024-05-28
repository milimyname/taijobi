<script lang="ts">
	import { canIdrawMultipleTimes } from '$lib/utils/stores';
	import ReactComponent from './ReactComponent.svelte';
	import { Excalidraw, MainMenu } from '@excalidraw/excalidraw';
	import type { ExcalidrawElement } from '@excalidraw/excalidraw/types/element/types.js';
	import type {
		AppState,
		ExcalidrawImperativeAPI,
		ExcalidrawInitialDataState
	} from '@excalidraw/excalidraw/types/types.js';
	import React from 'react';
	import { createEventDispatcher } from 'svelte';

	export let initialData: ExcalidrawInitialDataState = {};
	export let excalidrawAPI: ExcalidrawImperativeAPI;

	function setAPI(api: ExcalidrawImperativeAPI) {
		// console.log("SET API");
		excalidrawAPI = api;
		dispatcher('init');
	}

	const dispatcher = createEventDispatcher<{
		init: void;
		change: { elements: ExcalidrawElement[]; state: AppState };
		blob: Blob;
	}>();

	function onChange(elements: ExcalidrawElement[], state: AppState) {
		dispatcher('change', { elements, state });
	}
	const reactMainMenu = React.createElement(MainMenu, null, [
		React.createElement(MainMenu.DefaultItems.SaveAsImage, { key: 'SaveAsImage' }),
		React.createElement(MainMenu.DefaultItems.Export, { key: 'Export' })
	]);

	const button = React.createElement(
		'button',
		{
			onClick: () => {
				$canIdrawMultipleTimes = false;
			},
			className:
				'block z-[1000] mb-4 ml-4 h-10 mt-auto rounded-full border bg-white p-2 shadow-sm transition-all'
		},
		'Return'
	);
</script>

<ReactComponent
	{onChange}
	ref={setAPI}
	this={Excalidraw}
	{initialData}
	langCode="en-EN"
	children={button}
/>
