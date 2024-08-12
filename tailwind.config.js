import queries from '@tailwindcss/container-queries';
import typography from '@tailwindcss/typography';
import dottedBackground from 'tailwindcss-dotted-background';
import { fontFamily } from 'tailwindcss/defaultTheme';
import plugin from 'tailwindcss/plugin';

/** @type {import('tailwindcss').Config} */
const config = {
	darkMode: ['class'],
	content: ['./src/**/*.{html,js,svelte,ts}'],
	safelist: ['dark'],
	theme: {
		container: {
			center: true,
			padding: '2rem',
			screens: {
				'2xl': '1400px',
			},
		},
		extend: {
			colors: {
				border: 'hsl(var(--border) / <alpha-value>)',
				input: 'hsl(var(--input) / <alpha-value>)',
				ring: 'hsl(var(--ring) / <alpha-value>)',
				background: 'hsl(var(--background) / <alpha-value>)',
				foreground: 'hsl(var(--foreground) / <alpha-value>)',
				primary: {
					DEFAULT: 'hsl(var(--primary) / <alpha-value>)',
					foreground: 'hsl(var(--primary-foreground) / <alpha-value>)',
				},
				secondary: {
					DEFAULT: 'hsl(var(--secondary) / <alpha-value>)',
					foreground: 'hsl(var(--secondary-foreground) / <alpha-value>)',
				},
				destructive: {
					DEFAULT: 'hsl(var(--destructive) / <alpha-value>)',
					foreground: 'hsl(var(--destructive-foreground) / <alpha-value>)',
				},
				muted: {
					DEFAULT: 'hsl(var(--muted) / <alpha-value>)',
					foreground: 'hsl(var(--muted-foreground) / <alpha-value>)',
				},
				accent: {
					DEFAULT: 'hsl(var(--accent) / <alpha-value>)',
					foreground: 'hsl(var(--accent-foreground) / <alpha-value>)',
				},
				popover: {
					DEFAULT: 'hsl(var(--popover) / <alpha-value>)',
					foreground: 'hsl(var(--popover-foreground) / <alpha-value>)',
				},
				card: {
					DEFAULT: 'hsl(var(--card) / <alpha-value>)',
					foreground: 'hsl(var(--card-foreground) / <alpha-value>)',
				},
				success: '#47A992',
				error: '#D80032',
			},
			borderRadius: {
				'4xl': 'calc(var(--radius) + 2rem)',
				lg: 'var(--radius)',
				md: 'calc(var(--radius) - 2px)',
				sm: 'calc(var(--radius) - 4px)',
			},
			fontFamily: {
				sans: [...fontFamily.sans],
			},
			backgroundImage: {
				alphabetGreen:
					'linear-gradient(131deg, #C4DFDF 6.22%, rgba(210, 233, 233, 0.68) 55.03%, #47A992 96.27%);',
			},
			screens: {
				xm: '400px',
				xmm: '350px',
			},
			boxShadow: {
				profile: '0px -18px 10px 0px rgba(64, 168, 240, 0.10)',
				pricing: ' 0px -18px 10px 0px rgba(130, 197, 247x, 0.10)',
				'search-drawer-footer': '0px -16px 40px 0px rgba(0, 0, 0, 0.2)',
				logo: '0px 4px 3px 0px rgba(0, 0, 0, 0.40) inset, 0px 4px 4px 0px rgba(0, 0, 0, 0.25);',
			},
			height: {
				17: '17rem',
			},
		},
	},
	plugins: [
		typography,
		dottedBackground,
		queries,
		plugin(function ({ addVariant }) {
			addVariant('not-last', '&>*:not(:last-child)');
		}),
	],
};

export default config;
