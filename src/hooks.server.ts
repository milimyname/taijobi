import PocketBase from 'pocketbase';
import { sequence } from '@sveltejs/kit/hooks';

// PocketBase auth store middleware
async function auth({ event, resolve }) {
	const prod = process.env.NODE_ENV === 'production' ? true : false;

	event.locals.pb = new PocketBase(import.meta.env.VITE_POCKETBASE_URL);

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
	response.headers.set(
		'set-cookie',
		event.locals.pb.authStore.exportToCookie({ sameSite: 'Lax', secure: prod })
	);

	return response;
}

export const handle = sequence(auth);
