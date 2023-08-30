import { redirect } from '@sveltejs/kit';

/** @type {import('./$types').PageLoad} */
export const load = async ({ locals }) => {
	locals.pb.authStore.clear();

	throw redirect(303, '/login');
};
