import type { PageServerLoad } from './$types';

export const load = (async ({ locals }) => {
	try {
		const posts = await locals.pb.collection('posts').getFirstListItem('draft=false', {
			fields: 'title, id, description',
			sort: '-created'
		});

		return {
			posts
		};
	} catch (e) {
		console.log(e);
	}
}) satisfies PageServerLoad;
