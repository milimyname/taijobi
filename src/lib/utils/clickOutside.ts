export function clickOutside(node: Node, callback: () => void) {
	// the node has been mounted in the DOM

	window.addEventListener('click', handleClick);
	window.addEventListener('touchstart', handleTouch);

	const targets = [
		'nav',
		'.previousLetter',
		'.nextLetter',
		'.flashcard',
		'.add-collection-btn',
		'.add-form-btn',
		'.kanji-search',
		'.feedback-btn',
		'.edit-feedback',
		'.quiz-form',
		'.alphabet',
		'.flashcard-completion-btn',
		'.flaschards-carousel',
		'.search-btn'
	];

	function handleClick(e: MouseEvent) {
		// Ensure e.target is an instance of Element
		if (!(e.target instanceof Element)) return;

		if (targets.some((target) => (e.target as Element).closest(target))) return;

		if (!node.contains(e.target as Node)) callback();
	}

	function handleTouch(e: TouchEvent) {
		// Ensure e.target is an instance of Element
		if (!(e.target instanceof Element)) return;

		if (targets.some((target) => (e.target as Element).closest(target))) return;

		if (!node.contains(e.target)) callback();
	}

	return {
		destroy() {
			// the node has been removed from the DOM
			window.removeEventListener('click', handleClick);
			window.removeEventListener('touchstart', handleTouch);
		}
	};
}
