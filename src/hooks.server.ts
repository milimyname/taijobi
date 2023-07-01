import { PUBLIC_POCKETBASE_URL } from '$env/static/public';
import PocketBase from 'pocketbase';
import { sequence } from '@sveltejs/kit/hooks';

// Protect all routes in the protectedPaths array
// const protectedPaths = ['/'];

// async function protect({ event, resolve }) {
// 	if (!protectedPaths.includes(event.url.pathname)) return resolve(event);

// 	const session = await event.locals.getSession();

// 	if (!session) throw redirect(303, '/login');

// 	return resolve(event);
// }

// PocketBase auth store middleware
async function auth({ event, resolve }) {
	event.locals.pb = new PocketBase(PUBLIC_POCKETBASE_URL);

	// load the store data from the request cookie string
	event.locals.pb.authStore.loadFromCookie(event.request.headers.get('cookie') || '');

	try {
		// get an up-to-date auth store state by verifying and refreshing the loaded auth model (if any)
		event.locals.pb.authStore.isValid && (await event.locals.pb.collection('users').authRefresh());
	} catch (_) {
		// clear the auth store on failed refresh
		event.locals.pb.authStore.clear();
	}

	const response = await resolve(event);

	// send back the default 'pb_auth' cookie to the client with the latest store state
	response.headers.append('set-cookie', event.locals.pb.authStore.exportToCookie(), {
		secure: false
	});

	return response;
}

export const handle = sequence(auth);
