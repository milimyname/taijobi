import { showAppNav, showNav, isLongPress, lastPoint } from '$lib/utils/stores';

export function handleUserIconClick() {
	let longPress;
	isLongPress.subscribe((n) => (longPress = n));
	if (!longPress) showNav.update((n) => !n);
	isLongPress.set(false); // Reset the long press flag
	showAppNav.set(false); // Hide the app nav
}

export function handleMenuIconClick() {
	showAppNav.update((n) => !n);
	showNav.set(false);
}

export function handleLongPress() {
	return setTimeout(() => {
		isLongPress.set(true);
		showNav.set(false);
	}, 500);
}

export const handleCancelPress = (longPressTimer: any) => {
	clearTimeout(longPressTimer);
};

export function clearCanvas(ctx: any, canvas: any) {
	// Clear the entire canvas
	ctx.clearRect(0, 0, canvas.width, canvas.height);

	// Reset the lastPoint
	lastPoint.set({ x: 0, y: 0 });
}

export function getRandomNumber(min: number, max: number) {
	return Math.floor(Math.random() * (max - min + 1)) + min;
}
