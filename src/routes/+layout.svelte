<script>
	import '../app.css';

	// let audioUrl = '';

	// // Call api youtube-dl
	// onMount(async () => {
	// 	const response = await fetch('/api/youtube-dl', {
	// 		method: 'GET',
	// 		headers: {
	// 			'Content-Type': 'application/json'
	// 		}
	// 	});

	// 	if (!response.ok) throw new Error(response.statusText);

	// 	const { webm } = await response.json();
	// 	audioUrl = webm;
	// 	// const output = await response.json();
	// 	// console.log(output.formats.filter(({ ext }) => ext === 'mp4'));
	// 	// audioUrl = output.formats[34].url;
	// });
</script>

<!-- {#if audioUrl}
	<audio controls>
		<source src={audioUrl} type="audio/webm" />
		Your browser does not support the audio element.
	</audio>
{/if} -->

<slot />
