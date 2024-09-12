import { json, type RequestHandler } from '@sveltejs/kit';

export const GET: RequestHandler = async ({ locals }) => {
	// Check if the user is authenticated
	if (!locals.pb.authStore.model) return json({ error: 'User not authenticated' });

	const randomSearch = await locals.pb.collection('searches').getList(1, 1, {
		sort: '@random',
		filter: `user = "${locals.pb.authStore.model?.id}"`,
		fields: 'id',
	});

	return json({
		randomSearch: randomSearch.items[0],
	});
};
