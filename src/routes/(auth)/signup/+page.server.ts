import { signupSchema } from '$lib/utils/zodSchema';
import { fail, redirect } from '@sveltejs/kit';
import { superValidate, setError } from 'sveltekit-superforms';
import { zod } from 'sveltekit-superforms/adapters';

export const load = async ({ locals }) => {
	// Redirect if already logged in
	if (locals.pb.authStore.isValid) throw redirect(303, '/');
	// Server API:
	const form = await superValidate(zod(signupSchema));

	// Always return { form } in load and form actions.
	return { form };
};

export const actions = {
	default: async ({ request, locals }) => {
		const form = await superValidate(request, zod(signupSchema));

		// Convenient validation check:
		if (!form.valid) return fail(400, { form });

		// Check if passwords match
		if (form.data.password !== form.data.passwordConfirm)
			return setError(form, 'passwordConfirm', 'Passwords do not match.');

		try {
			await locals.pb.collection('users').create(form.data);
		} catch (error) {
			console.log('error', error);
			return setError(form, 'email', 'Email already exists.');
		}

		try {
			// Send verification email
			await locals.pb.collection('users').requestVerification(form.data.email);
		} catch (_) {
			// Check if email is not verified
			locals.pb.authStore.clear();
			return setError(form, 'email', 'Email already exists. Please verify your email address.');
		}

		// Login user
		await locals.pb.collection('users').authWithPassword(form.data.email, form.data.password);

		throw redirect(303, '/');
	},
};
