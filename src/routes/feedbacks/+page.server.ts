import { superValidate, setError } from 'sveltekit-superforms/server';
import { fail, redirect } from '@sveltejs/kit';
import { feedbackSchema } from '$lib/utils/zodSchema';

export const load = async ({ locals }) => {
	let feedbacks;

	const user = locals.pb.authStore.model;

	// Server API:
	const form = await superValidate(feedbackSchema);

	if (user?.role.includes('admin'))
		// Get all the flashcards
		feedbacks = await locals.pb.collection('feedbacks').getFullList();
	// Get all the flashcards
	else
		feedbacks = await locals.pb
			.collection('feedbacks')
			.getFullList({ filter: `userId = "${user?.id}"`, fields: 'id,name,description,device' });

	return { feedbacks, form };
};

export const actions = {
	create: async ({ request, locals }) => {
		const data = await request.formData();

		// Add userId to the data
		data.append('userId', locals.pb.authStore.model?.id);

		try {
			await locals.pb.collection('feedbacks').create(data);
		} catch (e) {
			console.log(e);
		}

		throw redirect(303, '/feedbacks');
	},
	update: async ({ request, locals }) => {
		const form = await superValidate(request, feedbackSchema);

		// Convenient validation check:
		if (!form.valid || !form.data.id)
			// Again, always return { form } and things will just work.
			return fail(400, { form });

		try {
			await locals.pb.collection('feedbacks').update(form.data.id, {
				name: form.data.name,
				description: form.data.description,
				device: form.data.device
			});
		} catch (_) {
			return setError(form, 'name', 'Something went wrong. Please try again later.');
		}

		return { form };
	},
	delete: async ({ request, locals }) => {
		const form = await superValidate(request, feedbackSchema);

		// Convenient validation check:
		if (!form.valid || !form.data.id)
			// Again, always return { form } and things will just work.
			return fail(400, { form });

		try {
			await locals.pb.collection('feedbacks').delete(form.data.id);
		} catch (_) {
			return setError(form, 'name', 'Something went wrong. Please try again later.');
		}

		return { form };
	}
};
