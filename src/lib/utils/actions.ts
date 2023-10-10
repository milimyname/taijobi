import {
	showAppNav,
	showNav,
	isLongPress,
	lastPoint,
	uploadingProfilePic
} from '$lib/utils/stores';
import { maxWidthCard, minWidthCard } from '$lib/utils/constants';
import { pocketbase } from './pocketbase';
import type { CropperDetails } from '$lib/utils/ambient.d.ts';
import type { Ctx } from '$lib/utils/ambient.d.ts';

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

export function clearCanvas(ctx: Ctx, canvas: HTMLCanvasElement) {
	// Clear the entire canvas
	ctx.clearRect(0, 0, canvas.width, canvas.height);

	// Reset the lastPoint
	lastPoint.set({ x: 0, y: 0 });
}

export function getRandomNumber(min: number, max: number) {
	return Math.floor(Math.random() * (max - min + 1)) + min;
}

// Flashcards page

// Sort the cards based on their current top position
export const sortCards = (cards: NodeListOf<HTMLButtonElement>) => {
	return Array.from(cards).sort((a, b) => {
		const topA = parseFloat(a.style.top) || 0;
		const topB = parseFloat(b.style.top) || 0;
		return topA - topB;
	});
};

export const handleScroll = (scroll: number, mountedCards: NodeListOf<HTMLButtonElement>) => {
	// Sort the cards based on their current top position
	const sortedCards = sortCards(mountedCards);

	sortedCards.forEach((card, i) => {
		const j = i + 1;
		const top = card.style.top;
		const topNum = +top.slice(0, top.length - 2);
		const newTop = topNum + scroll;

		// Calculate the card width based on its distance from the top of the viewport
		const cardTop = card.getBoundingClientRect().top;
		const normalizedWidth =
			minWidthCard + (maxWidthCard - minWidthCard) * (cardTop / window.innerHeight);

		// Apply the calculated width to the card
		card.style.width = `${normalizedWidth}px`;

		// Check if the card is off the section screen
		if (cardTop > window.innerHeight) {
			card.style.top = '0px';
			card.style.marginTop = `${0}px`;
			card.style.opacity = '0';
		} else if (cardTop < 0) {
			card.style.top = `${window.innerHeight - 10}px`;
			card.style.opacity = '0';
		} else {
			card.style.top = `${newTop}px`;
			card.style.opacity = '1';
			card.style.transform = 'translate(-50%, -50%) skew(0deg, 0deg)';
		}

		// Assign z-index based on the sorted order
		card.style.zIndex = `${j}`;
	});
};

// Upload a resized profile image to a square

export const uploadCroppedImage = async (
	imageSrc: string,
	cropperDetails: CropperDetails,
	inputFile: HTMLInputElement,
	userId: string
) => {
	// Create a new image element to load the selected image
	const selectedImage = new Image();
	selectedImage.src = imageSrc;

	// Set up an event handler to load the selected image
	selectedImage.onload = () => {
		// Create a canvas element to draw the cropped image
		const canvas = document.createElement('canvas');
		const ctx = canvas.getContext('2d');

		if (!ctx) return;

		// Set the canvas dimensions to match the cropped area
		canvas.width = cropperDetails.pixels.width;
		canvas.height = cropperDetails.pixels.height;

		// Draw the cropped image onto the canvas using cropperDetails
		ctx.drawImage(
			selectedImage, // Original image element
			cropperDetails.pixels.x, // x-coordinate of the top-left corner of the cropped area
			cropperDetails.pixels.y, // y-coordinate of the top-left corner of the cropped area
			cropperDetails.pixels.width, // width of the cropped area
			cropperDetails.pixels.height, // height of the cropped area
			0, // x-coordinate of the top-left corner of the destination rectangle
			0, // y-coordinate of the top-left corner of the destination rectangle
			cropperDetails.pixels.width, // width of the destination rectangle
			cropperDetails.pixels.height // height of the destination rectangle
		);

		// Convert the canvas content to a Blob
		canvas.toBlob(async (blob) => {
			// Make sure the blob is not null
			if (!blob) return;

			// Delete the previous profile image
			await pocketbase.collection('users').update(userId, {
				avatar: null,
				oauth2ImageUrl: null
			});

			// Upload the cropped image
			await pocketbase.collection('users').update(userId, {
				avatar: blob
			});

			// Reset variables and UI state
			uploadingProfilePic.set(false);
			imageSrc = '';
			inputFile.value = '';
		}, 'image/jpeg'); // Specify the desired image format here
	};
};

// Function to shuffle an array using the Fisher-Yates algorithm
export function shuffleArray(array: any[]) {
	for (let i = array.length - 1; i > 0; i--) {
		const j = Math.floor(Math.random() * (i + 1));
		[array[i], array[j]] = [array[j], array[i]];
	}
}
