import { RELEASES_URL } from './config';

declare const __APP_VERSION__: string;

export const APP_VERSION: string = __APP_VERSION__;

export { RELEASES_URL };

// Set to true when a release includes schema changes that require OPFS clear
export const IS_BREAKING = false;
