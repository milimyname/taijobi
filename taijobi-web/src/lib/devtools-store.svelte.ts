/**
 * DevTools instrumentation store — tracks WASM call timings.
 *
 * The `timed()` wrapper in wasm.ts pushes entries here. The DevTools WASM
 * tab reads from it reactively. Ring buffer capped at 200 entries so
 * memory doesn't grow unbounded during long sessions.
 */

const MAX_ENTRIES = 200;

export interface WasmCallEntry {
	id: number; // monotonic — unique even when multiple calls land in the same ms
	name: string;
	durationMs: number;
	timestamp: number; // Date.now()
}

class DevtoolsStore {
	#entries = $state<WasmCallEntry[]>([]);
	#callCount = $state(0);
	#nextId = 0;

	/** Push a new timing entry. Called by wasm.ts timed() wrapper. */
	record(name: string, durationMs: number): void {
		this.#callCount++;
		const entry: WasmCallEntry = {
			id: this.#nextId++,
			name,
			durationMs,
			timestamp: Date.now(),
		};
		// Ring buffer: drop oldest when full
		if (this.#entries.length >= MAX_ENTRIES) {
			this.#entries = [...this.#entries.slice(1), entry];
		} else {
			this.#entries = [...this.#entries, entry];
		}
	}

	get entries(): WasmCallEntry[] {
		return this.#entries;
	}

	get callCount(): number {
		return this.#callCount;
	}

	get avgMs(): number {
		if (this.#entries.length === 0) return 0;
		const sum = this.#entries.reduce((s, e) => s + e.durationMs, 0);
		return sum / this.#entries.length;
	}

	get slowest(): WasmCallEntry | null {
		if (this.#entries.length === 0) return null;
		return this.#entries.reduce((max, e) => (e.durationMs > max.durationMs ? e : max));
	}

	/** Recent entries (last N), newest first. */
	recent(n = 20): WasmCallEntry[] {
		return this.#entries.slice(-n).toReversed();
	}

	clear(): void {
		this.#entries = [];
		this.#callCount = 0;
	}
}

export const devtoolsStore = new DevtoolsStore();
