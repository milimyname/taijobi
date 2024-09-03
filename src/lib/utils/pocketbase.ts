import { dev } from '$app/environment';
import { browser } from '$app/environment';
import PocketBase from 'pocketbase';

const pocketbase = new PocketBase(
	dev ? import.meta.env.VITE_DEV_POCKETBASE_URL : import.meta.env.VITE_POCKETBASE_URL,
);

// the below 2 calls are only needed if you want to maintain the auth state in both browser and node
if (browser && document) {
	// these operations are now only executed in the browser
	pocketbase.authStore.loadFromCookie(document.cookie);
	pocketbase.authStore.onChange(() => {
		document.cookie = pocketbase.authStore.exportToCookie({ httpOnly: false });
	});
}

export { pocketbase };
