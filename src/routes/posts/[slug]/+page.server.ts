import type { PageServerLoad } from './$types';

export const load = (async ({ params, locals }) => {
	const postId = params.slug.split('-').pop();

	if (!postId) return;

	try {
		const posts = await locals.pb.collection('posts').getOne(postId, {
			fields: 'title, id, html, description',
			sort: '-created',
		});
		return {
			posts,
		};
	} catch (e) {
		console.log(e);
	}
}) satisfies PageServerLoad;
