import { redirect } from '@sveltejs/kit';

export const load = async ({ locals }) => {
	// Redirect if already logged in
	if (!locals.pb.authStore.isValid) throw redirect(303, '/login');
};
