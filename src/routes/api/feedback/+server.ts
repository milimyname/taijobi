import { json } from '@sveltejs/kit';

export async function POST({ request, locals }) {
	const formData = await request.formData();

	// Add user id to the feedback
	formData.append('userId', locals.pb.authStore.model.id);

	// Send feedback to the server
	try {
		await locals.pb.collection('feedbacks').create(formData);
	} catch (e) {
		console.log(e);
	}

	return json({ message: 'Feedback received!' });
}
