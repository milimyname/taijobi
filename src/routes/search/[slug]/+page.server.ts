import { redirect } from '@sveltejs/kit';

export const load = async ({ locals, params }) => {
	if (!locals.pb.authStore.isValid) throw redirect(401, '/login');

	const { slug } = params;

	// Redirect to home if no search query
	if (!slug) throw redirect(404, '/');

	try {
		const currentSearch = await locals.pb.collection('searches').getOne(slug, {
			expand: 'flashcard',
		});

		const searches = await locals.pb.collection('searches').getFullList({
			expand: 'flashcard.flashcardBox',
		});

		return {
			currentSearch,
			searches,
		};
	} catch (error) {
		console.error(error);
		throw redirect(307, '/');
	}
};
