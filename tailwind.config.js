const plugin = require('tailwindcss/plugin');

/** @type {import('tailwindcss').Config} */
export default {
	content: ['./src/**/*.{html,js,svelte,ts}'],
	theme: {
		extend: {
			colors: {
				primary: '#0A6EBD',
				success: '#47A992',
				error: '#D80032'
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
			}
		}
	},
	plugins: [
		require('@tailwindcss/forms'),
		require('tailwindcss-dotted-background'),
		require('@tailwindcss/container-queries'),
		plugin(function ({ addVariant }) {
			addVariant('not-last', '&>*:not(:last-child)');
		})
	]
};
