import { env } from '$env/dynamic/private';
import { DocumentProcessorServiceClient } from '@google-cloud/documentai';

let documentAI, processorName;

if (env.GCLOUD_AUTH_BASE_64) {
	const buffer = Buffer.from(env.GCLOUD_AUTH_BASE_64, 'base64');
	documentAI = new DocumentProcessorServiceClient({
		apiEndpoint: env.DOCUMENTAI_ENDPOINT,
		credentials: JSON.parse(buffer.toString('ascii')),
	});
	processorName = env.DOCUMENTAI_PROCESSOR_NAME;
} else {
	console.error('GCLOUD_AUTH_BASE_64 is not set');
	// Handle this case appropriately, maybe set documentAI to null or throw an error
}

export { documentAI, processorName };
