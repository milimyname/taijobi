import { documentAI, processorName } from '$lib/server/google-documentai';
import { convertToFurigana } from '$lib/server/kuroshiro';
import { json } from '@sveltejs/kit';
import PocketBase from 'pocketbase';

async function process(file: File, pb: PocketBase, recordID: string) {
	// Convert the file to base64
	const fileBuffer = await file.arrayBuffer();
	const encodedFile = Buffer.from(fileBuffer).toString('base64');

	const request = {
		name: processorName,
		rawDocument: {
			content: encodedFile,
			mimeType: file.type,
		},
	};

	// console.log('Request:', JSON.stringify(request, null, 2));
	const [result] = await documentAI.processDocument(request);

	const { document } = result;

	// Extract text from the document
	const { text } = document;

	// Extract paragraphs from the first page
	const [page1] = document.pages;

	const { paragraphs } = page1;

	const extractedParagraphs = paragraphs.map((paragraph) => {
		const textAnchor = paragraph.layout.textAnchor;
		if (!textAnchor.textSegments || textAnchor.textSegments.length === 0) return '';

		const startIndex = textAnchor.textSegments[0].startIndex || 0;
		const endIndex = textAnchor.textSegments[0].endIndex;
		return text.substring(startIndex, endIndex);
	});

	// TODO: Save more data so that user can have an image with the text overlayed
	// Save the result to the database
	const record = await pb.collection('paragraphs').update(recordID, {
		ocr_data: JSON.stringify({
			fullText: await convertToFurigana(text),
			paragraphs: extractedParagraphs,
		}),
	});

	return {
		fullText: text,
		paragraphs: extractedParagraphs,
		record,
	};
}

export const POST = async ({ request, locals }) => {
	if (!locals.pb.authStore.isValid || !locals.pb.authStore.model)
		return json({ error: 'Unauthorized' });

	// Get request body as FormData
	const formData = await request.formData();

	const file = formData.get('files') as File;
	console.time('upload');

	// Check if the request contains a file
	if (!file) return json({ error: 'No file provided' });

	formData.append('user', locals.pb.authStore.model.id);

	// Upload it to the server
	const paragraphsRecord = await locals.pb.collection('paragraphs').create(formData);
	console.timeEnd('upload');

	// Process the file with Document AI
	if (file) {
		try {
			console.time('process');

			const processedDocument = await process(file, locals.pb, paragraphsRecord.id);

			console.timeEnd('process');
			return json({
				message: 'File received and processed',
				fullText: processedDocument.fullText,
				paragraphs: processedDocument.paragraphs,
				paragraphsRecordID: paragraphsRecord.id,
				record: processedDocument.record,
			});
		} catch (error) {
			console.error('Error processing document:', error);
			return json({ error: 'Error processing document' }, { status: 500 });
		}
	} else {
		return json({ error: 'No file provided' }, { status: 400 });
	}
};
