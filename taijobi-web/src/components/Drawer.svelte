<script lang="ts">
	import type { Snippet } from 'svelte';
	import type { Attachment } from 'svelte/attachments';
	import { Spring } from 'svelte/motion';
	import { onDestroy, untrack } from 'svelte';
	import { drawerStore } from '$lib/drawer.svelte';

	interface Props {
		open: boolean;
		onclose: () => void;
		snaps?: number[];
		children: Snippet<
			[
				{
					content: Attachment;
					handle: Attachment;
					footer: Attachment;
					height: number;
				}
			]
		>;
	}

	let { open, onclose, snaps, children }: Props = $props();

	const id =
		typeof crypto.randomUUID === 'function'
			? crypto.randomUUID()
			: `${Date.now()}-${Math.random().toString(36).slice(2)}`;
	drawerStore.register(id);
	onDestroy(() => drawerStore.unregister(id));

	let nested = $derived(drawerStore.nestedAbove(id));
	let hasNested = $derived(nested > 0);
	let stackDepth = $derived(Math.max(0, drawerStore.depth(id)));
	let baseZ = $derived(50 + stackDepth * 10);

	const getSnaps = () => {
		const vh = window.innerHeight;
		if (snaps) return [0, ...snaps.map((s) => vh * s)];
		return [0, vh * 0.55, vh * 0.88];
	};

	const height = new Spring(0, { stiffness: 0.15, damping: 0.82 });

	let sheetRef: HTMLElement | undefined = $state();
	let contentRef: HTMLElement | undefined = $state();
	let handleRef: HTMLElement | undefined = $state();
	let isDragging = $state(false);
	let wasOpen = $state(false);

	// Touch state
	let startY = 0;
	let startHeight = 0;
	let lastY = 0;
	let lastTime = 0;
	let velocity = 0;
	let isDraggingSheet = false;

	// Wheel state — desktop trackpad / mouse wheel parity with touch drag.
	// Without this, scrolling the sheet with the wheel does nothing (the handle/
	// empty area) or only scrolls the inner list (content); you can't expand/
	// collapse the sheet at all on desktop.
	let wheelSnapTimer: ReturnType<typeof setTimeout> | undefined;
	let lastWheelTime = 0;
	let wheelVelocity = 0;
	let isWheeling = false;

	const isVisible = $derived(height.current > 5);
	const isExpanded = $derived.by(() => {
		const s = getSnaps();
		return height.current >= (s[s.length - 1] ?? 600) - 5;
	});

	$effect(() => {
		if (isVisible) {
			untrack(() => drawerStore.setOpen(id, true));
			return () => untrack(() => drawerStore.setOpen(id, false));
		}
	});

	$effect(() => {
		const el = sheetRef;
		if (el) untrack(() => drawerStore.setEl(id, el));
	});

	const portal: Attachment = (node) => {
		const el = node as HTMLElement;
		document.body.appendChild(el);
		return () => el.remove();
	};

	$effect(() => {
		if (contentRef) {
			contentRef.style.overflowY = isExpanded && !isDraggingSheet ? 'auto' : 'hidden';
		}
	});

	const footerReady = $derived.by(() => {
		const s = getSnaps();
		const threshold = (s[1] ?? 300) * 0.4;
		return height.current > threshold;
	});

	$effect(() => {
		if (open) {
			document.documentElement.classList.add('sheet-active');
			return () => {
				document.documentElement.classList.remove('sheet-active');
			};
		}
	});

	$effect(() => {
		if (open) {
			wasOpen = true;
			const s = getSnaps();
			height.target = s[1];
		} else {
			height.target = 0;
		}
	});

	let savedScrollY = 0;

	function lockScroll() {
		if (document.body.style.position === 'fixed') return;
		savedScrollY = window.scrollY;
		document.body.style.overflow = 'hidden';
		document.body.style.position = 'fixed';
		document.body.style.top = `-${savedScrollY}px`;
		document.body.style.width = '100%';
	}

	function unlockScroll() {
		if (drawerStore.openCount > 0) return;
		document.body.style.overflow = '';
		document.body.style.position = '';
		document.body.style.top = '';
		document.body.style.width = '';
		window.scrollTo(0, savedScrollY);
	}

	$effect(() => {
		if (isVisible) {
			lockScroll();
			return () => unlockScroll();
		}
	});

	onDestroy(() => {
		if (document.body.style.position === 'fixed' && drawerStore.openCount <= 1) {
			document.body.style.overflow = '';
			document.body.style.position = '';
			document.body.style.top = '';
			document.body.style.width = '';
			window.scrollTo(0, savedScrollY);
		}
	});

	$effect(() => {
		if (wasOpen && height.current < 15 && !isDragging && height.target === 0) {
			wasOpen = false;
			if (open) onclose();
		}
	});

	let dimOpacity = $derived(nested > 0 ? Math.min(nested * 0.06, 0.15) : 0);

	function onKeydown(e: KeyboardEvent) {
		if (e.key === 'Escape' && open && !hasNested) {
			height.target = 0;
		}
	}

	const onSheet: Attachment = (node) => {
		const el = node as HTMLElement;
		sheetRef = el;
		el.addEventListener('touchstart', onTouchStart, { passive: false });
		el.addEventListener('touchmove', onTouchMove, { passive: false });
		el.addEventListener('touchend', onTouchEnd);
		el.addEventListener('wheel', onWheel, { passive: false });
		return () => {
			el.removeEventListener('touchstart', onTouchStart);
			el.removeEventListener('touchmove', onTouchMove);
			el.removeEventListener('touchend', onTouchEnd);
			el.removeEventListener('wheel', onWheel);
			sheetRef = undefined;
		};
	};

	const onContent: Attachment = (node) => {
		const el = node as HTMLElement;
		contentRef = el;
		el.style.flex = '1';
		el.style.minHeight = '0';
		el.style.overflowY = 'hidden';
		el.style.overscrollBehavior = 'contain';
		el.style.touchAction = 'pan-y';
		return () => {
			contentRef = undefined;
		};
	};

	function onHandleClick() {
		if (isDragging || hasNested) return;
		const s = getSnaps();
		const medium = s[1];
		const max = s[s.length - 1];
		height.target = Math.abs(height.current - medium) < 20 ? max : medium;
	}

	const onHandle: Attachment = (node) => {
		const el = node as HTMLElement;
		handleRef = el;
		el.style.touchAction = 'none';
		el.style.cursor = 'pointer';
		el.addEventListener('click', onHandleClick);
		return () => {
			el.removeEventListener('click', onHandleClick);
			handleRef = undefined;
		};
	};

	let footerRef: HTMLElement | undefined = $state();

	const onFooter: Attachment = (node) => {
		const el = node as HTMLElement;
		footerRef = el;
		el.style.flexShrink = '0';
		el.style.transition = 'opacity 0.3s ease, transform 0.3s ease';
		return () => {
			footerRef = undefined;
		};
	};

	$effect(() => {
		if (footerRef) {
			if (footerReady) {
				footerRef.style.opacity = '1';
				footerRef.style.transform = 'translateY(0)';
			} else {
				footerRef.style.opacity = '0';
				footerRef.style.transform = 'translateY(12px)';
			}
		}
	});

	// Wheel: same arbitration as touch — when the inner list is scrolled past
	// its top, wheel events scroll the list; when at top and scrolling up, they
	// collapse the sheet. When collapsed, wheel expands it. Snap 150ms after
	// the last wheel tick to let momentum-scroll deliver its tail.
	function onWheel(e: WheelEvent) {
		if (hasNested) return;
		const hitHandle = handleRef?.contains(e.target as Node);
		const hitContent = contentRef?.contains(e.target as Node);
		if (!hitHandle && !hitContent) return;

		if (hitContent && !hitHandle) {
			// Mid-wheel snap-back: if we were dragging the sheet with the wheel
			// and the user reverses at full expansion, lock back to fully-expanded
			// before letting the list scroll take over.
			if (isExpanded && isWheeling) {
				clearTimeout(wheelSnapTimer);
				isWheeling = false;
				isDragging = false;
				wheelVelocity = 0;
				const s = getSnaps();
				height.target = s[s.length - 1];
			}

			if (!contentRef) return;

			// Same arbitration as touch: scroll content until it can't scroll
			// further, then start dragging the sheet. This matches iOS sheets
			// and prevents the "sheet collapses while I'm scrolling the list"
			// feel that happens at mid-snap positions.
			const isAtTop = contentRef.scrollTop <= 1;
			const isAtBottom =
				contentRef.scrollTop + contentRef.clientHeight >= contentRef.scrollHeight - 1;
			const noScroll = contentRef.scrollHeight <= contentRef.clientHeight + 1;

			if (noScroll) {
				e.preventDefault();
				applyWheelDelta(e.deltaY);
				return;
			}
			// Scrolling up (deltaY < 0) at top of content → drag sheet toward close/collapse.
			if (e.deltaY < 0 && isAtTop) {
				e.preventDefault();
				applyWheelDelta(e.deltaY);
				return;
			}
			// Scrolling down (deltaY > 0) at bottom of content with room to expand → grow sheet.
			if (e.deltaY > 0 && isAtBottom && !isExpanded) {
				e.preventDefault();
				applyWheelDelta(e.deltaY);
				return;
			}
			// Otherwise let the content scroll naturally.
			return;
		}

		// Handle or sheet-chrome wheel → always move the sheet.
		e.preventDefault();
		applyWheelDelta(e.deltaY);
	}

	function applyWheelDelta(deltaY: number) {
		isWheeling = true;
		isDragging = true;

		const now = Date.now();
		const dt = now - lastWheelTime;
		if (dt > 0 && dt < 200) {
			wheelVelocity = deltaY / dt;
		}
		lastWheelTime = now;

		const s = getSnaps();
		const maxSnap = s[s.length - 1];
		let newHeight = height.target + deltaY;
		if (newHeight > maxSnap) {
			const overflow = newHeight - maxSnap;
			newHeight = maxSnap + overflow * 0.15;
		}
		height.target = Math.max(0, newHeight);

		clearTimeout(wheelSnapTimer);
		wheelSnapTimer = setTimeout(() => {
			velocity = wheelVelocity;
			wheelVelocity = 0;
			isDragging = false;
			isWheeling = false;
			performSnap();
		}, 150);
	}

	function onTouchStart(e: TouchEvent) {
		if (hasNested) return;
		startY = e.touches[0].clientY;
		lastY = startY;
		lastTime = Date.now();
		velocity = 0;
		startHeight = height.current;
		isDragging = true;
		isDraggingSheet = false;

		const isHandle = handleRef?.contains(e.target as Node);
		const isContent = contentRef?.contains(e.target as Node);

		if (isHandle) {
			isDraggingSheet = true;
		} else if (!isContent) {
			isDraggingSheet = true;
		}
	}

	function takeOverDrag(currentY: number) {
		isDraggingSheet = true;
		startY = currentY;
		startHeight = height.current;
	}

	function onTouchMove(e: TouchEvent) {
		if (hasNested) return;
		const currentY = e.touches[0].clientY;
		const currentTime = Date.now();

		const timeDelta = currentTime - lastTime;
		if (timeDelta > 0) {
			velocity = (lastY - currentY) / timeDelta;
		}
		lastY = currentY;
		lastTime = currentTime;

		if (!isDraggingSheet && contentRef) {
			// Arbitration: let the content scroll whenever it still can in the
			// drag direction; only drag the sheet when the content has
			// scroll-exhausted toward that edge (or has no overflow at all).
			//
			// velocity convention:
			//   velocity > 0 → finger moving UP (content should scroll down)
			//   velocity < 0 → finger moving DOWN (content should scroll up)
			const isAtTop = contentRef.scrollTop <= 1;
			const isAtBottom =
				contentRef.scrollTop + contentRef.clientHeight >= contentRef.scrollHeight - 1;
			const noScroll = contentRef.scrollHeight <= contentRef.clientHeight + 1;

			if (noScroll) {
				// Nothing to scroll — any drag belongs to the sheet.
				takeOverDrag(currentY);
			} else if (velocity < -0.05 && isAtTop) {
				// Pulling down with content already at top → collapse/close sheet.
				takeOverDrag(currentY);
			} else if (velocity > 0.05 && isAtBottom && !isExpanded) {
				// Pulling up with content at bottom and sheet not yet maxed →
				// expand sheet to the next snap. At full expansion, further pull
				// just hits the overflow damping in applyWheelDelta / touchmove.
				takeOverDrag(currentY);
			}
			// Otherwise: let the content scroll naturally.
		}

		if (isDraggingSheet) {
			if (e.cancelable) e.preventDefault();
			const deltaY = startY - currentY;
			const s = getSnaps();
			const maxSnap = s[s.length - 1];
			let newHeight = startHeight + deltaY;
			if (newHeight > maxSnap) {
				const overflow = newHeight - maxSnap;
				newHeight = maxSnap + overflow * 0.15;
			}
			height.target = Math.max(-20, newHeight);
		}
	}

	function onTouchEnd() {
		performSnap();
		isDragging = false;
		isDraggingSheet = false;
		velocity = 0;
	}

	function performSnap() {
		const current = height.current;
		const s = getSnaps();
		const sortedSnaps = s.toSorted((a, b) => a - b);
		const minSnap = sortedSnaps[0];
		const maxSnap = sortedSnaps[sortedSnaps.length - 1];
		const velocityThreshold = 0.4;

		let targetSnap: number;

		if (Math.abs(velocity) > velocityThreshold) {
			if (velocity > 0) {
				targetSnap = sortedSnaps.find((snap) => snap > current) ?? maxSnap;
			} else {
				targetSnap = sortedSnaps.toReversed().find((snap) => snap < current) ?? minSnap;
			}
		} else {
			targetSnap = sortedSnaps.reduce((prev, curr) =>
				Math.abs(curr - current) < Math.abs(prev - current) ? curr : prev
			);
		}

		height.target = targetSnap;
	}
</script>

<svelte:window onkeydown={onKeydown} />

{#if open || isVisible}
	<!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions -->
	<div
		class="sheet-backdrop"
		onclick={() => {
			if (!hasNested) height.target = 0;
		}}
		style:opacity={Math.min(1, height.current / 300) * 0.5}
		style:z-index={baseZ}
		{@attach portal}
	></div>

	<div
		class="sheet-root"
		class:indented={nested > 0}
		style:height="{Math.max(0, height.current)}px"
		style:visibility={isVisible ? 'visible' : 'hidden'}
		style:z-index={baseZ + 1}
		style:--indent-scale={1 - nested * 0.04}
		style:--indent-y="{nested * -8}px"
		data-open={open ? '' : undefined}
		data-swiping={isDragging ? '' : undefined}
		{@attach onSheet}
		{@attach portal}
		role="dialog"
		aria-modal="true"
	>
		{@render children({
			content: onContent,
			handle: onHandle,
			footer: onFooter,
			height: height.current
		})}
		{#if dimOpacity > 0}
			<div class="sheet-nested-dim" style:opacity={dimOpacity}></div>
		{/if}
	</div>
{/if}

<style>
	.sheet-backdrop {
		position: fixed;
		inset: 0;
		background: black;
	}

	.sheet-root {
		position: fixed;
		bottom: 0;
		left: 0;
		right: 0;
		max-width: 42rem;
		margin: 0 auto;
		background: white;
		border-radius: 20px 20px 0 0;
		box-shadow: 0 -4px 30px rgba(0, 0, 0, 0.08);
		display: flex;
		flex-direction: column;
		will-change: height, transform;
		overflow: hidden;
		transform-origin: center bottom;
		transform: scale(var(--indent-scale, 1)) translateY(var(--indent-y, 0px));
		transition: transform 0.4s cubic-bezier(0.32, 0.72, 0, 1);
	}

	:global(.dark) .sheet-root {
		background: #1e293b;
	}

	.sheet-root.indented {
		pointer-events: none;
	}

	.sheet-nested-dim {
		position: absolute;
		inset: 0;
		border-radius: inherit;
		background: black;
		pointer-events: none;
		z-index: 999;
		transition: opacity 0.4s cubic-bezier(0.32, 0.72, 0, 1);
	}
</style>
