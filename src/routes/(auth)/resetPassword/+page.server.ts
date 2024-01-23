import { superValidate, setError } from 'sveltekit-superforms/server';
import { fail, redirect } from '@sveltejs/kit';
import { resetPasswordSchema } from '$lib/utils/zodSchema';

/** @type {import('./$types').PageServerLoad} */
export const load = async ({ locals }) => {
	// Redirect if already logged in
	if (locals.pb.authStore.isValid) throw redirect(303, '/');

	// Server API:
	const form = await superValidate(resetPasswordSchema);

	// Always return { form } in load and form actions.
	return { form };
};

/** @type {import('./$types').Actions} */
export const actions = {
	default: async ({ request, locals }) => {
		const form = await superValidate(request, resetPasswordSchema);

		// Convenient validation check:
		if (!form.valid) return fail(400, { form });

		// Send password reset email
		try {
			await locals.pb.collection('users').requestPasswordReset(form.data.email);
		} catch (_) {
			return setError(form, 'email', 'Invalid email or username');
		}

		throw redirect(303, '/');
	}
};
