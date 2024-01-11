import { superValidate, setError } from 'sveltekit-superforms/server';
import { fail } from '@sveltejs/kit';
import { feedbackSchema } from '$lib/utils/zodSchema';

export const load = async ({ locals }) => {
	let feedbacks;

	const user = locals.pb.authStore.model;

	// Server API:
	const form = await superValidate(feedbackSchema);

	if (user?.role.includes('admin'))
		// Get all the flashcards
		feedbacks = await locals.pb.collection('feedbacks').getFullList({
			fields: 'id,name,description,device'
		});
	// Get all the flashcards
	else
		feedbacks = await locals.pb
			.collection('feedbacks')
			.getFullList({ filter: `userId = "${user?.id}"`, fields: 'id,name,description,device' });

	return { feedbacks, form };
};

export const actions = {
	create: async ({ request, locals }) => {
		const form = await superValidate(request, feedbackSchema);

		// Convenient validation check:
		if (!form.valid)
			// Again, always return { form } and things will just work.
			return fail(400, { form });

		// Auth with pb
		try {
			await locals.pb.collection('feedbacks').create({
				name: form.data.name,
				description: form.data.description,
				device: form.data.device,
				userId: locals.pb.authStore.model?.id
			});
		} catch (_) {
			return setError(form, 'name', 'Something went wrong. Please try again later.');
		}

		return { form };
	},
	update: async ({ request, locals }) => {
		const form = await superValidate(request, feedbackSchema);

		// Convenient validation check:
		if (!form.valid || !form.data.id)
			// Again, always return { form } and things will just work.
			return fail(400, { form });

		console.log({
			da: form.data
		});

		// Auth with pb
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

		// Auth with pb
		try {
			console.log('deleted');
			await locals.pb.collection('feedbacks').delete(form.data.id);
		} catch (_) {
			return setError(form, 'name', 'Something went wrong. Please try again later.');
		}

		return { form };
	}
};
