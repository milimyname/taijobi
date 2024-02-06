import { superValidate, setError } from 'sveltekit-superforms/server';
import { fail, redirect } from '@sveltejs/kit';
import { profileData } from '$lib/utils/zodSchema';

/** @type {import('./$types').PageServerLoad} */
export const load = async ({ parent }) => {
	const { isLoggedIn } = await parent();
	if (!isLoggedIn) redirect(303, '/login');

	const form = await superValidate(profileData);

	return { form };
};

/** @type {import('./$types').Actions} */
export const actions = {
	changeProfileData: async ({ request, locals }) => {
		const form = await superValidate(request, profileData);

		// Convenient validation check:
		if (!form.valid)
			// Again, always return { form } and things will just work.
			return fail(400, { form });

		// Update username if it is not taken
		if (form.data.username !== locals.pb.authStore.model?.username) {
			try {
				await locals.pb.collection('users').update(locals.pb.authStore.model?.id, {
					username: form.data.username
				});
			} catch (_) {
				setError(form, 'username', 'Username is already taken.');
			}
		}

		// Update email if it is not taken
		if (form.data.email && form.data.email !== locals.pb.authStore.model?.email) {
			try {
				await locals.pb.collection('users').requestEmailChange(form.data.email);
			} catch (_) {
				setError(form, 'email', 'Email is already taken.');
			}
		}

		return { form };
	},
	requestPasswordReset: async ({ locals }) => {
		// Send password reset email
		try {
			await locals.pb.collection('users').requestPasswordReset(locals.pb.authStore.model?.email);
		} catch (e) {
			console.log(e);
		}
	}
};
