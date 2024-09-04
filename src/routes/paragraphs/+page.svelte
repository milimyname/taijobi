<script lang="ts">
	import { onMount } from 'svelte';
	import Dropzone from 'dropzone';
	import { toast } from 'svelte-sonner';
	import { paragraphs } from '$lib/utils/stores';
	import { goto } from '$app/navigation';
	import { page } from '$app/stores';

	let dropzoneElement: HTMLElement;
	let loading = false;
	let worker: Worker;
	let dropzone: Dropzone;
	let isMounted = false;

	onMount(() => {
		isMounted = true;
		let cleanup = () => {};

		const setup = async () => {
			const UploadWorker = await import('$lib/workers/upload-worker?worker');
			worker = new UploadWorker.default();

			dropzone = new Dropzone(dropzoneElement, {
				url: '/api/paragraphs',
				maxFilesize: 5,
				maxFiles: 1,
				paramName: 'files',
				acceptedFiles: '.jpg,.png,.gif',
				dictDefaultMessage: 'Drop files here or click to upload',
				autoProcessQueue: false, // Disable auto processing
			});

			let processingResolve: () => void;
			let processingReject: (reason?: any) => void;

			// Promise for processing
			const processingPromise = new Promise<void>((resolve, reject) => {
				processingResolve = resolve;
				processingReject = reject;
			});

			// Handle worker messages
			worker.onmessage = (event) => {
				const { action, success, result, paragraphsRecordID, error } = event.data;

				if (action === 'upload') {
					if (success) {
						$paragraphs = [...$paragraphs, result.record];

						// Start processing after successful upload
						worker.postMessage({
							action: 'process',
							data: {
								prompt: result.paragraphs.join('').replaceAll('\n', ' '),
								recordID: result.paragraphsRecordID,
							},
							paragraphsRecordID: result.paragraphsRecordID,
						});
					} else {
						loading = false;
						processingReject(`Failed to upload the image: ${error}`);
					}
				} else if (action === 'process') {
					if (success) {
						processingResolve();
						toast('Processing complete!', {
							description: `Click to view results`,
							action: {
								label: 'View',
								onClick: () => goto(`/paragraphs/${paragraphsRecordID}`),
							},
						});

						// if user still on the same page, redirect to the new paragraph page
						if (isMounted && $page.url.pathname === '/paragraphs')
							goto(`/paragraphs/${paragraphsRecordID}`);
					} else {
						processingReject(`Failed to process the image: ${error}`);
					}
					loading = false;
				}
			};

			dropzone.on('addedfile', async (file) => {
				loading = true;
				const formData = new FormData();
				formData.append('files', file);

				// Convert file to ArrayBuffer
				const arrayBuffer = await file.arrayBuffer();

				// Promise for uploading
				const uploadPromise = new Promise<void>((resolve, reject) => {
					worker.postMessage(
						{
							action: 'upload',
							data: {
								filename: file.name,
								type: file.type,
								size: file.size,
								arrayBuffer: arrayBuffer,
							},
						},
						[arrayBuffer],
					); // Transfer the ArrayBuffer
					resolve(); // Resolve immediately, the processingPromise handles further logic
				});

				// Show upload toast
				toast.promise(uploadPromise, {
					loading: 'Uploading image...',
					success: 'Image uploaded successfully!',
					error: (error) => `Upload failed: ${error}`,
				});

				// Show processing toast
				toast.promise(processingPromise, {
					loading: 'Processing image...',
					success: 'Image processed successfully!',
					error: (error) => `Processing failed: ${error}`,
					finally: () => {
						worker.terminate();
					},
				});
			});

			cleanup = () => {
				if (dropzone) dropzone.destroy();
			};
		};

		setup();

		return () => {
			cleanup();
			isMounted = false;
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
