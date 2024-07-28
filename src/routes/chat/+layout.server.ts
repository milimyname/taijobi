import { redirect } from '@sveltejs/kit';

export const load = async ({ locals }) => {
	if (!locals.pb.authStore.isValid) redirect(401, '/login');

	const chats = await locals.pb.collection('chats').getFullList({
		filter: `user = "${locals.pb.authStore.model?.id}"`,
		fields: 'id,name,created,messages',
	});

	return { chats };
};
