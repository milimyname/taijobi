import { OPENAI_API_KEY } from '$env/static/private';
import OpenAI from 'openai';

export const openai = new OpenAI({
	apiKey: OPENAI_API_KEY || process.env.OPENAI_API_KEY,
});
