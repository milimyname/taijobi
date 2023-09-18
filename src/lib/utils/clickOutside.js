export function clickOutside(node) {
	// the node has been mounted in the DOM

	window.addEventListener('click', handleClick);
	window.addEventListener('touchstart', handleTouch);

	function handleClick(e) {
		if (
			e.target.closest('nav') ||
			e.target.closest('.previousLetter') ||
			e.target.closest('.nextLetter') ||
			e.target.closest('.flashcard') ||
			e.target.closest('.add-collection-btn') ||
			e.target.closest('.add-form-btn') ||
			e.target.closest('.kanji-search') ||
			e.target.closest('.leave-feedback') ||
			e.target.closest('.edit-feedback') ||
			e.target.closest('.quiz-form')
		)
			return;
		if (!node.contains(e.target)) node.dispatchEvent(new CustomEvent('outsideclick'));
	}

	function handleTouch(e) {
		if (
			e.target.closest('nav') ||
			e.target.closest('.previousLetter') ||
			e.target.closest('.nextLetter') ||
			e.target.closest('.flashcard') ||
			e.target.closest('.add-collection-btn') ||
			e.target.closest('.add-form-btn') ||
			e.target.closest('.kanji-search') ||
			e.target.closest('.leave-feedback') ||
			e.target.closest('.edit-feedback') ||
			e.target.closest('.quiz-form')
		)
			return;
		if (!node.contains(e.target)) node.dispatchEvent(new CustomEvent('outsideclick'));
	}

	return {
		destroy() {
			// the node has been removed from the DOM
			window.removeEventListener('click', handleClick);
			window.removeEventListener('touchstart', handleTouch);
		}
	};
}
