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
			}
		}
	},
	plugins: [require('@tailwindcss/forms')]
};
