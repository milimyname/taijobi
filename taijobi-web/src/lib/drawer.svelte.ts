/**
 * Global drawer store — tracks all open drawers for stacking coordination.
 *
 * Reactive: register/unregister/setOpen create new Map → triggers $derived
 * Non-reactive: setEl/setHeight mutate in-place → no $derived cascade at 60fps
 */

interface DrawerEntry {
	id: string;
	el: HTMLElement | null;
	height: number;
	isOpen: boolean;
	openedAt: number;
}

class DrawerStore {
	#drawers = $state<Map<string, DrawerEntry>>(new Map());

	register(id: string) {
		if (this.#drawers.has(id)) return;
		const next = new Map(this.#drawers);
		next.set(id, { id, el: null, height: 0, isOpen: false, openedAt: 0 });
		this.#drawers = next;
	}

	unregister(id: string) {
		if (!this.#drawers.has(id)) return;
		const next = new Map(this.#drawers);
		next.delete(id);
		this.#drawers = next;
	}

	setOpen(id: string, open: boolean) {
		const entry = this.#drawers.get(id);
		if (!entry || entry.isOpen === open) return;
		const next = new Map(this.#drawers);
		next.set(id, { ...entry, isOpen: open, openedAt: open ? Date.now() : 0 });
		this.#drawers = next;
	}

	setEl(id: string, el: HTMLElement | null) {
		const entry = this.#drawers.get(id);
		if (entry) entry.el = el;
	}

	setHeight(id: string, h: number) {
		const entry = this.#drawers.get(id);
		if (entry) entry.height = h;
	}

	openDrawers(): DrawerEntry[] {
		const open: DrawerEntry[] = [];
		for (const entry of this.#drawers.values()) {
			if (entry.isOpen) open.push(entry);
		}
		return open.toSorted((a, b) => a.openedAt - b.openedAt);
	}

	get openCount(): number {
		let count = 0;
		for (const entry of this.#drawers.values()) {
			if (entry.isOpen) count++;
		}
		return count;
	}

	depth(id: string): number {
		const sorted = this.openDrawers();
		return sorted.findIndex((e) => e.id === id);
	}

	nestedAbove(id: string): number {
		const sorted = this.openDrawers();
		const idx = sorted.findIndex((e) => e.id === id);
		if (idx < 0) return 0;
		return sorted.length - 1 - idx;
	}
}

export const drawerStore = new DrawerStore();
