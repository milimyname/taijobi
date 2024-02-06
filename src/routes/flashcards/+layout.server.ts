/** @type {import('./$types').LayoutServerLoad} */
export const load = async ({ locals }) => {
	if (!locals.pb.authStore.isValid)
		return {
			isLoggedIn: false,
			isAdmin: false
		};

	const user = structuredClone(locals.pb.authStore.model);
	return {
		isAdmin: user?.role.includes('admin')
	};
};
