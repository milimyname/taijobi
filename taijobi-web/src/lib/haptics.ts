/**
 * Haptic feedback via the Vibration API.
 * Silently no-ops on browsers without support (most desktops, iOS Safari).
 */

function vibrate(pattern: number | number[]): void {
	if (typeof navigator === 'undefined') return;
	if (typeof navigator.vibrate !== 'function') return;
	try {
		navigator.vibrate(pattern);
	} catch {
		// Some browsers throw if called too frequently
	}
}

export const haptics = {
	/** Light tap — button press, selection. */
	tap: () => vibrate(8),
	/** Medium thump — confirmation, card flip. */
	medium: () => vibrate(15),
	/** Success pattern — correct answer. */
	success: () => vibrate([10, 40, 10]),
	/** Error buzz — wrong answer, failed action. */
	error: () => vibrate([30, 30, 30])
};
