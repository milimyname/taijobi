/**
 * Sonner-style stacked toast store.
 * Supports multiple simultaneous toasts with auto-dismiss,
 * undo callbacks, hover-to-pause, and swipe-to-dismiss.
 */

export interface Toast {
	id: string;
	message: string;
	onUndo?: (() => Promise<void>) | null;
	createdAt: number;
	duration: number; // ms
	paused: boolean;
	remaining: number; // ms remaining when paused
}

const MAX_VISIBLE = 3;
const DEFAULT_DURATION = 5000;

class ToastStore {
	#toasts = $state<Toast[]>([]);
	#timers = new Map<string, ReturnType<typeof setTimeout>>();

	get toasts(): Toast[] {
		return this.#toasts;
	}

	get visible(): boolean {
		return this.#toasts.length > 0;
	}

	get message(): string {
		return this.#toasts[this.#toasts.length - 1]?.message ?? '';
	}

	get hasUndo(): boolean {
		return this.#toasts.some((t) => t.onUndo != null);
	}

	show(msg: string, onUndo?: () => Promise<void>, duration = DEFAULT_DURATION) {
		const id = `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
		const toast: Toast = {
			id,
			message: msg,
			onUndo: onUndo ?? null,
			createdAt: Date.now(),
			duration,
			paused: false,
			remaining: duration
		};

		this.#toasts = [...this.#toasts, toast];

		if (this.#toasts.length > MAX_VISIBLE + 2) {
			const removed = this.#toasts[0];
			this.#clearTimer(removed.id);
			this.#toasts = this.#toasts.slice(1);
		}

		this.#startTimer(id, duration);
		return id;
	}

	dismiss(id?: string) {
		if (!id) {
			const last = this.#toasts[this.#toasts.length - 1];
			if (last) this.dismiss(last.id);
			return;
		}
		this.#clearTimer(id);
		this.#toasts = this.#toasts.filter((t) => t.id !== id);
	}

	async triggerUndo(id?: string) {
		const toast = id
			? this.#toasts.find((t) => t.id === id)
			: this.#toasts.findLast((t) => t.onUndo != null);
		if (!toast?.onUndo) return;
		const cb = toast.onUndo;
		this.dismiss(toast.id);
		await cb();
	}

	pauseAll() {
		for (const toast of this.#toasts) {
			if (!toast.paused) {
				toast.paused = true;
				toast.remaining = Math.max(0, toast.remaining - (Date.now() - toast.createdAt));
				this.#clearTimer(toast.id);
			}
		}
		this.#toasts = [...this.#toasts];
	}

	resumeAll() {
		for (const toast of this.#toasts) {
			if (toast.paused) {
				toast.paused = false;
				toast.createdAt = Date.now();
				this.#startTimer(toast.id, toast.remaining);
			}
		}
		this.#toasts = [...this.#toasts];
	}

	#startTimer(id: string, ms: number) {
		this.#clearTimer(id);
		this.#timers.set(
			id,
			setTimeout(() => {
				this.dismiss(id);
			}, ms)
		);
	}

	#clearTimer(id: string) {
		const timer = this.#timers.get(id);
		if (timer) {
			clearTimeout(timer);
			this.#timers.delete(id);
		}
	}
}

export const toastStore = new ToastStore();
