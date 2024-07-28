import { kuroshiro } from '$lib/server/kuroshiro';
import { json } from '@sveltejs/kit';
import { z } from 'zod';

const FuriganaSchema = z.object({
	paragraphs: z.array(z.string()),
});

export const POST = async ({ request, locals }) => {
	if (!locals.pb.authStore.isValid || !locals.pb.authStore.model)
		return json({ error: 'Unauthorized' });

	const body = await request.json();

	// Validate the input
	const validatedData = FuriganaSchema.safeParse(body);

	if (!validatedData.success) return json({ error: validatedData.error });

	const paragraphs = validatedData.data.paragraphs;

	const convertedToOneParagraph = paragraphs
		.map((paragraph) => paragraph.replace(/\n/g, ''))
		.join('');

	const furigana = await kuroshiro.convert(convertedToOneParagraph, {
		to: 'hiragana',
		mode: 'furigana',
	});

	return json({ furigana });
};
