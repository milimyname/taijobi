<script lang="ts">
	import { Toaster as Sonner, type ToasterProps as SonnerProps } from 'svelte-sonner';

	type $$Props = SonnerProps;
</script>

<Sonner
	position="top-center"
	class="toaster group"
	richColors
	toastOptions={{
		classes: {
			toast:
				'add-btn group toast group-[.toaster]:bg-background group-[.toaster]:text-foreground group-[.toaster]:border-border group-[.toaster]:shadow-lg',
			description: 'group-[.toast]:text-muted-foreground',
			actionButton: 'group-[.toast]:border-primary group-[.toast]:text-primary-foreground',
			cancelButton: 'group-[.toast]:bg-muted group-[.toast]:text-muted-foreground',
		},
	}}
	{...$$restProps}
/>
