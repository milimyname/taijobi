import { superValidate, setError } from 'sveltekit-superforms';
import { fail } from '@sveltejs/kit';
import { feedbackSchema } from '$lib/utils/zodSchema';
import { zod } from 'sveltekit-superforms/adapters';

export const load = async ({ locals }) => {
	let feedbacks;

	const user = locals.pb.authStore.model;

	if (!locals.pb.authStore.isValid) {
		return {
			isLoggedIn: false,
			isAdmin: false
		};
	}

	if (user?.role.includes('admin')) {
		// Get all the flashcards
		feedbacks = await locals.pb.collection('feedbacks').getFullList();
	} else {
		// Get all the flashcards
		feedbacks = await locals.pb.collection('feedbacks').getFullList({
			filter: `userId = "${user?.id}"`
		});
	}

	return {
		feedbacks,
		form: await superValidate(zod(feedbackSchema)),
		isLoggedIn: true,
		isAdmin: user?.role.includes('admin')
	};
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

		return;
	},
	update: async ({ request, locals }) => {
		const form = await superValidate(request, zod(feedbackSchema));

		

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
		const form = await superValidate(request, zod(feedbackSchema));

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
