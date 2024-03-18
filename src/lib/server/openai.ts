import OpenAI from 'openai';
import { OPENAI_API_KEY } from '$env/static/private';
import { dev } from '$app/environment';

export const openai = new OpenAI({
	apiKey: dev ? OPENAI_API_KEY : process.env.OPENAI_API_KEY
});
