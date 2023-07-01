import { superValidate } from 'sveltekit-superforms/server';
import { fail, redirect } from '@sveltejs/kit';
import { loginSchema } from '$lib/utils/zodSchema.js';

export const load = async ({ locals }) => {
	// Redirect if already logged in
	if (locals.pb.authStore.isValid) throw redirect(303, '/');
	// Server API:
	const form = await superValidate(loginSchema);

	// Always return { form } in load and form actions.
	return { form };
};

export const actions = {
	default: async ({ request, locals }) => {
		const form = await superValidate(request, loginSchema);

		// Convenient validation check:
		if (!form.valid)
			// Again, always return { form } and things will just work.
			return fail(400, { form });

		// Auth with pb
		try {
			await locals.pb.collection('users').authWithPassword(form.data.email, form.data.password);

			// Add user to locals
			// locals.user = record;
		} catch (_) {
			form.errors.email = ['Invalid email or password.'];
			return { form };
		}

		throw redirect(303, '/');
	}
};
