import { DOCUMENTAI_PROCESSOR_NAME, DOCUMENTAI_ENDPOINT } from '$env/static/private';
import { DocumentProcessorServiceClient } from '@google-cloud/documentai';

export const documentAI = new DocumentProcessorServiceClient({
	apiEndpoint: DOCUMENTAI_ENDPOINT || process.env.DOCUMENTAI_ENDPOINT,
});

export const processorName = DOCUMENTAI_PROCESSOR_NAME || process.env.DOCUMENTAI_PROCESSOR_NAME;
