import { redirect } from '@sveltejs/kit';

interface ParagraphsAPIResponse {
	files: string[];
	formatted_ai_data: {
		meaning: string;
		kanaWithFurigana: string;
		detailed: {
			kana: string;
			hiragana: string;
			meaning: string;
		}[];
	};
	ocr_data: {
		fullText: string;
		paragraphs: string[];
	};
	created: number;
	collectionId: string;
	id: string;
}

export const load = async ({ locals, params }) => {
	if (!locals.pb.authStore.isValid) redirect(303, '/login');

	const { slug } = params;

	// Redirect to home if no search query
	if (!slug) throw redirect(404, '/');

	const record = (await locals.pb.collection('paragraphs').getOne(slug, {
		fields: 'id,files,formatted_ai_data,ocr_data,created,collectionId',
	})) as ParagraphsAPIResponse;

	if (!record) return redirect(404, '/paragraphs');

	const url = locals.pb.files.getUrl(record, record.files[0]);

	return {
		paragraphs: {
			...record,
			url,
		},
	};
};
