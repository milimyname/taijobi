import {
	showAppNav,
	showNav,
	isLongPress,
	lastPoint,
	uploadingProfilePic
} from '$lib/utils/stores';
import { pocketbase } from './pocketbase';
import type { CropperDetails } from '$lib/utils/ambient.d.ts';

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

export function clearCanvas(ctx: CanvasRenderingContext2D, canvas: HTMLCanvasElement) {
	if (!canvas || !ctx) return;

	// Clear the entire canvas
	ctx.clearRect(0, 0, canvas.width, canvas.height);

	// Reset the lastPoint
	lastPoint.set({ x: 0, y: 0 });
}

export function getRandomNumber(min: number, max: number) {
	return Math.floor(Math.random() * (max - min + 1)) + min;
}

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

// Function to convert a string to a ruby tag
export function convertToRubyTag(input: string) {
	// Split the input string by slashes first to get character-annotation pairs
	const pairs = input.split('/').filter(Boolean);

	// Initialize the ruby tag
	let rubyTag = '';

	// Process each pair in steps of 2 (character and its annotation)
	for (let i = 0; i < pairs.length; i += 2) {
		// Check if the annotation exists
		if (pairs[i + 1]) {
			// Create a ruby annotation for each pair
			rubyTag += '<ruby>' + pairs[i] + '<rt>' + pairs[i + 1] + '</rt></ruby>';
		} else {
			// If the annotation doesn't exist, just add the character
			rubyTag += pairs[i];
		}
	}

	return rubyTag;
}

// Function to handle whether the device is touch screen
export function isTouchScreen() {
	if (typeof window === 'undefined') return false;

	return 'ontouchstart' in window || navigator.maxTouchPoints > 0 || navigator.maxTouchPoints > 0;
}

// Function to convert text to speech
export async function convertTextToSpeech(input: string) {
	try {
		const res = await fetch('/api/openai', {
			method: 'POST',
			headers: {
				'Content-Type': 'application/json'
			},
			body: JSON.stringify({ input, type: 'audio' })
		});

		if (!res.ok) throw new Error('Failed to fetch audio');

		const data = await res.json();

		return data.fileName;
	} catch (e) {
		console.error(e);
	}
}
