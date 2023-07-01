import { superValidate } from 'sveltekit-superforms/server';
import { fail, redirect } from '@sveltejs/kit';
import { signupSchema } from '$lib/utils/zodSchema.ts';

export const load = async ({ locals }) => {
	// Redirect if already logged in
	if (locals.pb.authStore.isValid) throw redirect(303, '/');
	// Server API:
	const form = await superValidate(signupSchema);

	// Always return { form } in load and form actions.
	return { form };
};

export const actions = {
	default: async ({ request, locals }) => {
		const form = await superValidate(request, signupSchema);

		// Convenient validation check:
		if (!form.valid) return fail(400, { form });

		// Check if passwords match
		if (form.data.password !== form.data.passwordConfirm) {
			form.errors.passwordConfirm = ['Passwords do not match.'];
			return { form };
		}

		try {
			// Create user
			await locals.pb.collection('users').create(form.data);
			// Add user to locals
			await locals.pb.collection('users').authWithPassword(form.data.email, form.data.password);
		} catch (_) {
			form.errors.email = ['Email is already in use.'];
			return { form };
		}

		throw redirect(303, '/');
	}
};
