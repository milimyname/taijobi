export function clickOutside(node: Node, callback: () => void) {
	// the node has been mounted in the DOM

	window.addEventListener('click', handleClick);
	window.addEventListener('touchstart', handleTouch);

	function handleClick(e: MouseEvent) {
		// Ensure e.target is an instance of Element
		if (!(e.target instanceof Element)) return;

		if (
			e.target.closest('nav') ||
			e.target.closest('.previousLetter') ||
			e.target.closest('.nextLetter') ||
			e.target.closest('.flashcard') ||
			e.target.closest('.add-collection-btn') ||
			e.target.closest('.add-form-btn') ||
			e.target.closest('.kanji-search') ||
			e.target.closest('.feedback-btn') ||
			e.target.closest('.edit-feedback') ||
			e.target.closest('.quiz-form') ||
			e.target.closest('.alphabet')
		)
			return;
		if (!node.contains(e.target)) callback();
	}

	function handleTouch(e: TouchEvent) {
		// Ensure e.target is an instance of Element
		if (!(e.target instanceof Element)) return;

		if (
			e.target.closest('nav') ||
			e.target.closest('.previousLetter') ||
			e.target.closest('.nextLetter') ||
			e.target.closest('.flashcard') ||
			e.target.closest('.add-collection-btn') ||
			e.target.closest('.add-form-btn') ||
			e.target.closest('.kanji-search') ||
			e.target.closest('.feedback-btn') ||
			e.target.closest('.edit-feedback') ||
			e.target.closest('.quiz-form') ||
			e.target.closest('.alphabet')
		)
			return;
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
