<!-- <script lang="ts">
	import { SVG } from '@svgdotjs/svg.js';

	// Function to create SVG from Kanji data

	let container: string | HTMLElement;
	function createKanjiSVG(kanjiData: {}) {
		// Get the container element

		// Create an SVG.js drawing
		const draw = SVG().addTo(container).size(100, 100);

		// Create the Kanji shape (You may need to customize this based on the data)
		const kanjiShape = draw.rect(100, 100).fill('black');

		// You can add more SVG elements to create the desired representation
		// For example, you can add text elements to display the readings and meanings.

		// Return the SVG.js draw instance in case you need to modify it later
		return draw;
	}

	// Usage example:
	const kanjiData = {
		勝: {
			// Kanji data here...
		}
	};

	const kanjiSVG = createKanjiSVG(kanjiData['勝']);

	console.log(kanjiSVG);
</script>

<div id="kanji-container" bind:this={container} />
<h1>hi</h1> -->
