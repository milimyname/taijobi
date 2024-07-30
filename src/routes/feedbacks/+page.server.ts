import { feedbackSchema } from '$lib/utils/zodSchema';
import { fail, redirect } from '@sveltejs/kit';
import { superValidate, setError } from 'sveltekit-superforms';
import { zod } from 'sveltekit-superforms/adapters';

export const load = async ({ locals, parent }) => {
	const { isAdmin } = await parent();

	// Redirect if not logged in
	if (!locals.pb.authStore.isValid) redirect(401, '/login');

	const feedbacks = isAdmin
		? await locals.pb.collection('feedbacks').getFullList()
		: await locals.pb.collection('feedbacks').getFullList({
				filter: `userId = "${locals.pb.authStore.model?.id}"`,
			});

	// Get only the user's feedbacks
	return {
		feedbacks,
		form: await superValidate(zod(feedbackSchema)),
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
				description: form.data.description,
			});
		} catch (_) {
			return setError(form, 'description', 'Something went wrong. Please try again later.');
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
			return setError(form, 'description', 'Something went wrong. Please try again later.');
		}

		return { form };
	},
};
