export const load = async ({ locals }) => {
	if (!locals.pb.authStore.isValid)
		return {
			isLoggedIn: false,
		};

	return {
		user: structuredClone(locals.pb.authStore.model),
		isLoggedIn: true,
	};
};
