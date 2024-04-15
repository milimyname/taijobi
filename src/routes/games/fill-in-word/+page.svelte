<script>
	let sentence = ['The', '___', 'jumps', 'over', 'the', '___', 'dog.'];
	let words = ['quick', 'brown', 'lazy', 'fox'];
	let filledBlanks = Array(sentence.length).fill('');

	function handleDragStart(event) {
		event.dataTransfer.setData('text', event.target.innerText);
	}

	function allowDrop(event) {
		event.preventDefault();
	}

	function handleDrop(event, i) {
		event.preventDefault();
		const newWord = event.dataTransfer.getData('text');

		// Check if there is already a word in the blank
		if (filledBlanks[i]) {
			// Add the current word back to the list before replacing
			words.push(filledBlanks[i]);
		}

		filledBlanks[i] = newWord;
		// Remove the new word from the list of words
		words = words.filter((w) => w !== newWord);
	}

	function handleRemoveWord(i) {
		const word = filledBlanks[i];
		if (word) {
			// Add the word back to the list of words
			words.push(word);
			filledBlanks[i] = '';
		}
	}
</script>

<div>
	{#each sentence as word, i}
		{#if word === '___'}
			<button
				on:drop|preventDefault={(event) => handleDrop(event, i)}
				on:dragover|preventDefault={allowDrop}
				on:click={() => handleRemoveWord(i)}
				class="blank"
			>
				{filledBlanks[i] || 'Drop word here'}
			</button>
		{:else}
			<span class="m-2">{word}</span>
		{/if}
	{/each}
	<div>
		{#each words as word}
			<button draggable="true" on:dragstart={handleDragStart} class="word">
				{word}
			</button>
		{/each}
	</div>
</div>

<style>
	.blank,
	.word {
		border: 2px solid gray;
		padding: 10px;
		min-width: 50px;
		display: inline-block;
		cursor: pointer;
		background-color: white;
	}
	.word {
		margin: 5px;
		cursor: grab;
	}
</style>
