import { superValidate, setError } from 'sveltekit-superforms/server';
import { fail, redirect } from '@sveltejs/kit';
import { loginSchema } from '$lib/utils/zodSchema';

/** @type {import('./$types').PageServerLoad} */
export const load = async ({ locals, url }) => {
	// Redirect if already logged in
	if (locals.pb.authStore.isValid) throw redirect(303, '/');
	// Server API:
	// const form = await superValidate(loginSchema);

	const authMethods = await locals.pb?.collection('users').listAuthMethods();
	if (!authMethods) {
		return {
			authProviderRedirect: '',
			authProviderState: ''
		};
	}

	const redirectURL = `${url.origin}/auth/oauth2-redirect`;
	const googleAuthProvider = authMethods.authProviders[0];
	const authProviderRedirect = `${googleAuthProvider.authUrl}${redirectURL}`;
	const state = googleAuthProvider.state;
	const codeVerifier = googleAuthProvider.codeVerifier;

	// Always return { form } in load and form actions.
	return {
		form: await superValidate(loginSchema),
		authProviderRedirect,
		authProviderState: state,
		codeVerifier
	};
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
			await locals.pb.collection('users').authWithPassword(form.data.email, form.data.password);
			if (!locals.pb.authStore.model?.verified) {
				locals.pb.authStore.clear();
				return setError(form, 'email', 'Email is not verified. Check ur email inbox.');
			}
		} catch (_) {
			return setError(form, 'email', 'Invalid email or password.');
		}

		throw redirect(303, '/');
	}
};
