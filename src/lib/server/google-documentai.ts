import { env } from '$env/dynamic/private';
import { DocumentProcessorServiceClient } from '@google-cloud/documentai';

const buffer = Buffer.from(env.GCLOUD_AUTH_BASE_64, 'base64');

export const documentAI = new DocumentProcessorServiceClient({
	apiEndpoint: env.DOCUMENTAI_ENDPOINT,
	credentials: JSON.parse(buffer.toString('ascii')),
});

export const processorName = env.DOCUMENTAI_PROCESSOR_NAME;
