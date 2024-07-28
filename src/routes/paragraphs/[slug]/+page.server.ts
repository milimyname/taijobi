import { redirect } from '@sveltejs/kit';

export const load = async ({ locals, params }) => {
	if (!locals.pb.authStore.isValid) redirect(303, '/login');

	const { slug } = params;

	// Redirect to home if no search query
	if (!slug) throw redirect(404, '/');

	const record = await locals.pb.collection('paragraphs').getOne(slug, {
		fields: 'id,files,formatted_ai_data,ocr_data,created,collectionId',
	});

	if (!record) return redirect(404, '/paragraphs');

	const url = locals.pb.files.getUrl(record, record.files[0]);

	return {
		paragraphs: {
			...record,
			url,
		},
	};
};
