import { json } from '@sveltejs/kit';
import youtubedl from 'youtube-dl-exec';

/** @type {import('./$types').RequestHandler} */
export const GET = async () => {
	const output = await youtubedl('https://www.youtube.com/watch?v=Qc7_zRjH808', {
		dumpSingleJson: true,
		noCheckCertificates: true,
		noWarnings: true,
		preferFreeFormats: true,
		addHeader: ['referer:youtube.com', 'user-agent:googlebot']
		// extractAudio: true,
		// audioFormat: 'mp3'
	});

	return json({
		webm: output.requested_formats[1].url
	});
	// return json(output);
};
