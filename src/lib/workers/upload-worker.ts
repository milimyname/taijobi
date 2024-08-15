// upload-worker.ts
const workerScope = self as unknown as Worker;

type ParagraphsAPIResponse = {
	paragraphs: string[];
	paragraphsRecordID: string;
};

workerScope.onmessage = async (event) => {
	const { action, data } = event.data;

	if (action === 'upload') {
		await handleUpload(data);
	} else if (action === 'process') {
		await handleProcessing(data);
	}
};

async function handleUpload(data: {
	filename: string;
	type: string;
	size: number;
	arrayBuffer: ArrayBuffer;
}) {
	try {
		// Recreate the File object
		const file = new File([data.arrayBuffer], data.filename, { type: data.type });

		// Create a new FormData and append the file
		const formData = new FormData();
		formData.append('files', file);

		const response = await fetch('/api/paragraphs', {
			method: 'POST',
			body: formData,
		});

		if (!response.ok) throw new Error(`Failed to upload: ${response.statusText}`);

		const result = (await response.json()) as ParagraphsAPIResponse;
		workerScope.postMessage({ action: 'upload', success: true, result });
	} catch (error) {
		workerScope.postMessage({ action: 'upload', success: false, error: error.message });
	}
}

interface ProcessingData {
	prompt: string;
	recordID: string;
}

async function handleProcessing(data: ProcessingData) {
	try {
		const response = await fetch('/api/openai/paragraphs', {
			method: 'POST',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify(data),
		});

		if (!response.ok) throw new Error(`Failed to process: ${response.statusText}`);

		const result = await response.json();
		workerScope.postMessage({
			action: 'process',
			success: true,
			result,
			paragraphsRecordID: data.recordID,
		});
	} catch (error) {
		workerScope.postMessage({ action: 'process', success: false, error: error.message });
	}
}
