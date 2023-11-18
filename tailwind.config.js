import plugin from 'tailwindcss/plugin';
import typography from '@tailwindcss/typography';
import forms from '@tailwindcss/forms';
import dottedBackground from 'tailwindcss-dotted-background';
import queries from '@tailwindcss/container-queries';
import typography from '@tailwindcss/typography';

/** @type {import('tailwindcss').Config} */
export default {
	content: ['./src/**/*.{html,js,svelte,ts}'],
	theme: {
		container: {
			center: true,
			padding: '2rem',
			screens: {
				'2xl': '1440px',
			},
		},
		extend: {
			colors: {
				primary: '#0A6EBD',
				success: '#47A992',
				error: '#D80032',
				magnum: {
					'50': '#fff9ed',
					'100': '#fef2d6',
					'200': '#fce0ac',
					'300': '#f9c978',
					'400': '#f7b155',
					'500': '#f38d1c',
					'600': '#e47312',
					'700': '#bd5711',
					'800': '#964516',
					'900': '#793a15',
					'950': '#411c09',
				},
			},
			backgroundImage: {
				alphabetGreen:
					'linear-gradient(131deg, #C4DFDF 6.22%, rgba(210, 233, 233, 0.68) 55.03%, #47A992 96.27%);'
			},
			screens: {
				xm: '400px'
			},
			borderRadius: {
				'4xl': '2.5rem'
			},
			boxShadow: {
				profile: '0px -18px 10px 0px rgba(64, 168, 240, 0.10)',
				pricing: ' 0px -18px 10px 0px rgba(130, 197, 247x, 0.10)',
				logo: '0px 4px 3px 0px rgba(0, 0, 0, 0.40) inset, 0px 4px 4px 0px rgba(0, 0, 0, 0.25);'
			},
			height: {
				17: '17rem'
			},
			fontFamily: {
				sans: [
					'-apple-system',
					'BlinkMacSystemFont',
					'Segoe UI',
					'Roboto',
					'Oxygen',
					'Ubuntu',
					'Cantarell',
					'Fira Sans',
					'Droid Sans',
					'Helvetica Neue',
					'Arial',
					'sans-serif',
					'Apple Color Emoji',
					'Segoe UI Emoji',
					'Segoe UI Symbol',
				],
				mono: [
					'ui-monospace',
					'SFMono-Regular',
					'SF Mono',
					'Menlo',
					'Consolas',
					'Liberation Mono',
					'monospace',
				],
			},
			typography: (theme) => ({
				DEFAULT: {
				css: {
					code: {
					position: 'relative',
					borderRadius: theme('borderRadius.md'),
					},
				},
				},
			}),
		}
	},
	plugins: [
		forms,
		typography,
		dottedBackground,
		queries,
		plugin(function ({ addVariant }) {
			addVariant('not-last', '&>*:not(:last-child)');
		})
	]
};
