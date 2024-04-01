import { dev } from '$app/environment';
import PocketBase from 'pocketbase';

export const pocketbase = new PocketBase(
	dev ? import.meta.env.VITE_DEV_POCKETBASE_URL : import.meta.env.VITE_POCKETBASE_URL
);
