import { redirect } from '@sveltejs/kit';

/** @type {import('./$types').PageServerLoad} */
export const load = async ({ locals }) => {
	locals.pb.authStore.clear();

	throw redirect(303, '/login');
};
