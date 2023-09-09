import { superValidate } from 'sveltekit-superforms/server';
import { fail, redirect } from '@sveltejs/kit';
import { loginSchema } from '$lib/utils/zodSchema';

/** @type {import('./$types').PageServerLoad} */
export const load = async ({ locals }) => {
	// Redirect if already logged in
	if (locals.pb.authStore.isAdmin) throw redirect(303, '/');
	// Server API:
	const form = await superValidate(loginSchema);

	// Always return { form } in load and form actions.
	return { form };
};

/** @type {import('./$types').Actions} */
export const actions = {
	default: async ({ request, locals }) => {
		const form = await superValidate(request, loginSchema);

		// Convenient validation check:
		if (!form.valid)
			// Again, always return { form } and things will just work.
			return fail(400, { form });

		// Auth with pb
		try {
			const admin = await locals.pb.admins.authWithPassword(form.data.email, form.data.password);

			console.log(admin);
		} catch (_) {
			form.errors.email = ['Invalid email or password.'];
			return { form };
		}

		throw redirect(303, '/');
	}
};
