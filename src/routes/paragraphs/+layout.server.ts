import { redirect } from '@sveltejs/kit';

export const load = async ({ locals }) => {
	if (!locals.pb.authStore.isValid) redirect(303, '/login');

	const paragraphs = await locals.pb.collection('paragraphs').getFullList({
		filter: `user = "${locals.pb.authStore.model?.id}"`,
		fields: 'id,files,formatted_ai_data,ocr_data,created,name',
	});

	return { paragraphs };
};
