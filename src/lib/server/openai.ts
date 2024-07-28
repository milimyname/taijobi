import { env } from '$env/dynamic/private';
import { createOpenAI } from '@ai-sdk/openai';
import OpenAI from 'openai';

export const openai = new OpenAI({
	apiKey: env.OPENAI_API_KEY ?? '',
});

export const ai = createOpenAI({
	apiKey: env.OPENAI_API_KEY ?? '',
});
