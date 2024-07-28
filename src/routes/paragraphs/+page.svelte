<script lang="ts">
	import { onMount } from 'svelte';
	import Dropzone from 'dropzone';
	import { toast } from 'svelte-sonner';
	import { paragraphs } from '$lib/utils/stores';
	import { goto } from '$app/navigation';

	let dropzoneElement: HTMLElement;
	let loading: boolean = false;

	type ParagraphsAPIResponse = {
		paragraphs: string[];
		paragraphsRecordID: string;
	};

	onMount(() => {
		const dropzone = new Dropzone(dropzoneElement, {
			url: '/api/paragraphs',
			maxFilesize: 5, // MB
			maxFiles: 1,
			paramName: 'files',
			acceptedFiles: '.jpg,.png,.gif',
			dictDefaultMessage: 'Drop files here or click to upload',
		});

		dropzone.on('sending', () => {
			loading = true;

			const uploadPromise = new Promise<void>((resolve, reject) => {
				dropzone.on('success', async (_, response) => {
					try {
						$paragraphs = [...$paragraphs, response?.record];
						// await addFurigana($paragraphs);
						formatData(response);
						goto(`/paragraphs/${response.paragraphsRecordID}`);

						resolve();
					} catch (error) {
						reject(error);
					} finally {
						loading = false;
					}
				});

				dropzone.on('error', (file, errorMessage) => {
					console.error('Error uploading file:', errorMessage);
					reject(new Error(`Error uploading file: ${errorMessage}`));
					loading = false;
				});
			});

			toast.promise(uploadPromise, {
				loading: 'Processing image...',
				success: 'Processed image!',
				error: 'Failed to recognize the image. Please try again.',
			});
		});

		// async function addFurigana(paragraphs: RecordModel[]) {
		// 	const furiganaRes = await fetch('/api/text/furigana', {
		// 		method: 'POST',
		// 		headers: { 'Content-Type': 'application/json' },
		// 		body: JSON.stringify({ paragraphs }),
		// 	});

		// 	if (!furiganaRes.ok) throw new Error('Failed to fetch furigana');

		// 	toast.promise(Promise.resolve(), {
		// 		loading: 'Adding furigana to text...',
		// 		success: 'Added furigana!',
		// 		error: 'Failed to add furigana.',
		// 	});
		// }

		async function formatData(response: ParagraphsAPIResponse) {
			const prompt = response.paragraphs.join('').replaceAll('\n', ' ');

			const openaiRes = await fetch('/api/openai/paragraphs', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({
					prompt,
					recordID: response.paragraphsRecordID,
				}),
			});

			if (!openaiRes.ok) throw new Error('Failed to fetch OpenAI response');

			toast.promise(Promise.resolve(), {
				loading: 'Formatting text...',
				success: 'Formatted text!',
				error: 'Failed to format text.',
			});
		}

		return () => {
			dropzone.destroy();
		};
	});
</script>

<div
	bind:this={dropzoneElement}
	class="dropzone my-auto flex items-center justify-center rounded-lg border-4 border-dashed border-primary p-4"
>
	{#if !loading}
		<p class="dz-message">Drop files here or click to upload</p>
	{/if}
</div>
