import { loginSchema } from '$lib/utils/zodSchema';
import { fail, redirect } from '@sveltejs/kit';
import { superValidate, setError } from 'sveltekit-superforms';
import { zod } from 'sveltekit-superforms/adapters';

/** @type {import('./$types').PageServerLoad} */
export const load = async ({ locals }) => {
	// Redirect if already logged in
	if (locals.pb.authStore.isValid) throw redirect(303, '/');
	// Server API:
	const form = await superValidate(zod(loginSchema));

	// Always return { form } in load and form actions.
	return { form };
};

/** @type {import('./$types').Actions} */
export const actions = {
	default: async ({ request, locals }) => {
		const form = await superValidate(request, zod(loginSchema));

		// Convenient validation check:
		if (!form.valid)
			// Again, always return { form } and things will just work.
			return fail(400, { form });

		// Auth with pb
		try {
			await locals.pb.collection('users').authWithPassword(form.data.email, form.data.password);
		} catch (_) {
			return setError(form, 'email', 'Invalid email or password.');
		}

		if (!locals.pb.authStore.model?.role.includes('admin')) {
			locals.pb.authStore.clear();
			return setError(form, 'email', 'You are not an admin.');
		}

		throw redirect(303, '/');
	},
};
