import { json, type RequestHandler } from '@sveltejs/kit';
import Pocketbase from 'pocketbase';

async function getRandomSearch(pb: Pocketbase) {
	const collection = pb.collection('searches');
	const userId = pb.authStore.model?.id;

	// Get the total count of matching records
	const resultList = await collection.getList(1, 1, {
		filter: `user = "${userId}"`,
	});

	const totalItems = resultList.totalItems;

	if (totalItems === 0) {
		return null; // No matching records found
	}

	// Generate a random index
	const randomIndex = Math.floor(Math.random() * totalItems);

	// Fetch the random record
	const randomRecord = await collection.getList(randomIndex + 1, 1, {
		filter: `user = "${userId}"`,
		fields: 'id',
	});

	return randomRecord.items[0];
}

export const GET: RequestHandler = async ({ locals }) => {
	// Check if the user is authenticated
	if (!locals.pb.authStore.model) return json({ error: 'User not authenticated' });

	const randomSearch = await getRandomSearch(locals.pb);

	return json({
		randomSearch,
	});
};
