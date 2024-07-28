import { browser } from '$app/environment';
import eventsource from 'eventsource';

global.EventSource = eventsource;
