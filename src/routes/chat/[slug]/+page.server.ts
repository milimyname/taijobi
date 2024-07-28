import { redirect } from '@sveltejs/kit';

export const load = async ({ locals, params }) => {
	if (!locals.pb.authStore.isValid) redirect(401, '/login');

	const { slug } = params;

	// Redirect to home if no search query
	if (!slug) throw redirect(404, '/');

	const chat = await locals.pb.collection('chats').getOne(slug, {
		expand: 'messages',
	});

	if (!chat) return redirect(404, '/chat');

	return { messages: chat.expand?.messages ?? [] };
};
