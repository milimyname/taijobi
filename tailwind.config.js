/** @type {import('tailwindcss').Config} */
export default {
	content: ['./src/**/*.{html,js,svelte,ts}'],
	theme: {
		extend: {
			colors: {
				primary: '#0A6EBD'
			},
			screens: {
				xm: '400px'
			},
			borderRadius: {
				'4xl': '2.5rem'
			},
			boxShadow: {
				profile: '0px -18px 10px 0px rgba(64, 168, 240, 0.10)',
				pricing: ' 0px -18px 10px 0px rgba(130, 197, 247x, 0.10)'
			},
			height: {
				17: '17rem'
			}
		}
	},
	plugins: [require('@tailwindcss/forms'), require('tailwindcss-dotted-background')]
};
