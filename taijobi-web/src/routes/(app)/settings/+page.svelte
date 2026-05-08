<script lang="ts">
	import ContentCopy from '$lib/icons/ContentCopy.svelte';
	import Download from '$lib/icons/Download.svelte';
	import QrCode from '$lib/icons/QrCode.svelte';
	import Sync from '$lib/icons/Sync.svelte';
	import VpnKey from '$lib/icons/VpnKey.svelte';
	import Icon from '$lib/icons/Icon.svelte';
	import Drawer from '../../../components/Drawer.svelte';
	import { onMount } from 'svelte';
	import {
		getSyncKey,
		setSyncKey,
		clearSyncKey,
		isSyncEnabled,
		connectSync,
		disconnectSync,
		syncFull,
		getLastSyncTimestamp,
	} from '$lib/sync';
	import { syncWS } from '$lib/sync-ws.svelte';
	import { toastStore } from '$lib/toast.svelte';
	import { themeStore, type Theme } from '$lib/theme.svelte';
	import { pushStore } from '$lib/push.svelte';
	import { LS_KEY_BACKED_UP } from '$lib/config';
	import { generateQRSvg } from '$lib/qr';

	const themeOptions: { value: Theme; label: string; icon: string }[] = [
		{ value: 'light', label: 'Hell', icon: 'light_mode' },
		{ value: 'dark', label: 'Dunkel', icon: 'dark_mode' },
		{ value: 'system', label: 'System', icon: 'contrast' },
	];

	let syncKey = $state(getSyncKey() ?? '');
	let enabled = $state(isSyncEnabled());
	let inputKey = $state('');
	let syncing = $state(false);
	let lastSync = $state(getLastSyncTimestamp());
	// Drives the "back up your key!" nag — true until the user has explicitly
	// downloaded or password-manager-saved their key at least once.
	let keyBackedUp = $state(localStorage.getItem(LS_KEY_BACKED_UP) === '1');
	let qrSvg = $state('');
	let showQr = $state(false);
	let showSyncInfo = $state(false);

	function markBackedUp(): void {
		localStorage.setItem(LS_KEY_BACKED_UP, '1');
		keyBackedUp = true;
	}

	function generateKey(): void {
		const bytes = new Uint8Array(24);
		crypto.getRandomValues(bytes);
		const key = Array.from(bytes)
			.map((b) => b.toString(36).padStart(2, '0'))
			.join('')
			.slice(0, 32);
		syncKey = key;
		setSyncKey(key);
		enabled = true;
		// Fresh key — force the nag back on so the user has a chance to back it
		// up before something happens (uninstall, browser wipe, lost device).
		localStorage.removeItem(LS_KEY_BACKED_UP);
		keyBackedUp = false;
		connectSync();
		toastStore.show('Sync-Schlüssel generiert');
	}

	function downloadKey(): void {
		if (!syncKey) return;
		const stamp = new Date().toISOString().slice(0, 10);
		const body = `Taijobi Sync-Schlüssel
Erstellt: ${new Date().toLocaleString('de-DE')}

${syncKey}

Diesen Schlüssel sicher aufbewahren. Er ist deine Identität —
auf jedem Gerät, das du verbinden willst, fügst du genau diesen
Schlüssel ein. Ohne ihn lassen sich verschlüsselte Daten nicht
wiederherstellen.
`;
		const blob = new Blob([body], { type: 'text/plain;charset=utf-8' });
		const url = URL.createObjectURL(blob);
		const a = document.createElement('a');
		a.href = url;
		a.download = `taijobi-sync-key-${stamp}.txt`;
		document.body.appendChild(a);
		a.click();
		a.remove();
		URL.revokeObjectURL(url);
		markBackedUp();
		toastStore.show('Schlüssel heruntergeladen');
	}

	function handleShowQR(): void {
		if (!syncKey) return;
		// QR encodes a deep-link to /settings on this same origin so scanning
		// from another device's camera lands directly in Settings with the key
		// pre-filled (handled by the onMount block below).
		const url = `${window.location.origin}/settings?sync=${syncKey}`;
		qrSvg = generateQRSvg(url);
		showQr = true;
	}

	function closeQR(): void {
		showQr = false;
		// Mark backed-up once the user has at least seen the QR — they had a
		// chance to scan / save it. The "Habe ich" path also calls markBackedUp
		// directly via the nag dismiss button.
		markBackedUp();
	}

	onMount(() => {
		const params = new URLSearchParams(window.location.search);
		// Inbound QR scan: ?sync=<key> on /settings auto-fills the link input
		// so the user can confirm with one tap. Strip the param immediately so
		// reload doesn't re-trigger.
		const incoming = params.get('sync');
		if (incoming && !enabled) {
			inputKey = incoming;
			toastStore.show('Schlüssel aus QR-Code übernommen — bestätige unten.');
		}
		// Deep-link drawers from the command palette: /settings?show=qr or
		// ?show=sync-info. The QR variant only opens if there's a key to show.
		const show = params.get('show');
		if (show === 'qr' && enabled && syncKey) {
			handleShowQR();
		} else if (show === 'sync-info' && !enabled) {
			showSyncInfo = true;
		}
		if (incoming || show) {
			window.history.replaceState({}, '', window.location.pathname);
		}
	});

	function linkKey(): void {
		const key = inputKey.trim();
		if (!key) return;
		syncKey = key;
		setSyncKey(key);
		enabled = true;
		inputKey = '';
		// User pasted a key from another device — they already have it backed
		// up (it came from somewhere). No nag.
		markBackedUp();
		connectSync();
		toastStore.show('Sync-Schlüssel verknüpft');
	}

	function disconnect(): void {
		clearSyncKey();
		syncKey = '';
		enabled = false;
		toastStore.show('Sync getrennt');
	}

	async function manualSync(): Promise<void> {
		if (!syncKey || syncing) return;
		syncing = true;
		try {
			const result = await syncFull(syncKey);
			lastSync = Date.now();
			toastStore.show(`Sync: ${result.pushed} gepusht, ${result.pulled} gezogen`);
		} catch (e) {
			toastStore.show(`Sync fehlgeschlagen: ${e instanceof Error ? e.message : 'Fehler'}`);
		} finally {
			syncing = false;
		}
	}

	async function copyKey(): Promise<void> {
		if (!syncKey) return;
		await navigator.clipboard.writeText(syncKey);
		toastStore.show('Schlüssel kopiert');
	}

	function maskedKey(key: string): string {
		if (key.length <= 8) return key;
		return key.slice(0, 4) + '\u2022'.repeat(key.length - 8) + key.slice(-4);
	}

	function formatTimestamp(ts: number): string {
		if (ts === 0) return 'Noch nie';
		return new Date(ts).toLocaleString('de-DE', {
			day: '2-digit',
			month: '2-digit',
			year: 'numeric',
			hour: '2-digit',
			minute: '2-digit',
		});
	}

</script>

<div class="space-y-6 py-4">
	<!-- Theme -->
	<div>
		<p class="text-[11px] font-bold uppercase tracking-wider text-primary">Erscheinungsbild</p>
		<p class="mt-1 text-sm text-slate-500 dark:text-slate-400">
			Wähle dein bevorzugtes Design.
		</p>
	</div>
	<div class="grid grid-cols-3 gap-2">
		{#each themeOptions as opt (opt.value)}
			<button
				onclick={() => themeStore.set(opt.value)}
				class="flex flex-col items-center gap-1.5 rounded-xl border px-3 py-3 text-sm font-medium transition-colors {themeStore.theme === opt.value
					? 'border-primary bg-primary/10 text-primary'
					: 'border-slate-100 bg-white text-slate-600 hover:bg-slate-50 dark:border-white/5 dark:bg-white/5 dark:text-slate-300 dark:hover:bg-white/10'}"
			>
				<Icon name={opt.icon} class="text-xl" />
				{opt.label}
			</button>
		{/each}
	</div>

	<!-- Sync -->
	<div>
		<p class="text-[11px] font-bold uppercase tracking-wider text-primary">Sync</p>
		<p class="mt-1 text-sm text-slate-500 dark:text-slate-400">
			Mehrere Geräte synchronisieren. Kein Konto nötig.
		</p>
	</div>

	{#if enabled}
		<!-- Backup nag — appears after key generation, dismisses when the user
		     downloads or saves to password manager. Critical because losing the
		     key means losing access to all encrypted data on the sync server. -->
		{#if !keyBackedUp}
			<div class="rounded-2xl border border-amber-200 bg-amber-50 p-4 dark:border-amber-500/30 dark:bg-amber-500/10">
				<div class="flex items-start gap-3">
					<div class="mt-0.5 flex size-8 shrink-0 items-center justify-center rounded-lg bg-amber-200/60 dark:bg-amber-500/20">
						<VpnKey class="text-amber-700 dark:text-amber-400" />
					</div>
					<div class="min-w-0 flex-1">
						<p class="text-sm font-bold text-amber-900 dark:text-amber-200">
							Schl&uuml;ssel jetzt sichern
						</p>
						<p class="mt-1 text-xs leading-relaxed text-amber-800/80 dark:text-amber-300/80">
							Dein Sync-Schl&uuml;ssel ist deine Identit&auml;t. Geht er verloren
							(App deinstalliert, Browser zur&uuml;ckgesetzt, Ger&auml;t kaputt),
							sind deine verschl&uuml;sselten Daten unwiederbringlich weg.
						</p>
						<div class="mt-3 flex flex-wrap gap-2">
							<button
								type="button"
								onclick={handleShowQR}
								class="flex items-center gap-1.5 rounded-lg bg-amber-600 px-3 py-1.5 text-xs font-bold text-white shadow-sm transition-colors hover:bg-amber-700"
							>
								<QrCode class="text-[14px]" />
								Als QR-Code
							</button>
							<button
								onclick={downloadKey}
								class="flex items-center gap-1.5 rounded-lg border border-amber-300 bg-white px-3 py-1.5 text-xs font-bold text-amber-800 transition-colors hover:bg-amber-50 dark:border-amber-500/40 dark:bg-amber-500/10 dark:text-amber-200 dark:hover:bg-amber-500/20"
							>
								<Download class="text-[14px]" />
								Als Datei
							</button>
							<button
								onclick={markBackedUp}
								class="rounded-lg px-3 py-1.5 text-xs font-medium text-amber-700/80 transition-colors hover:bg-amber-100 dark:text-amber-400/80 dark:hover:bg-amber-500/10"
							>
								Habe ich
							</button>
						</div>
					</div>
				</div>
			</div>
		{/if}

		<!-- Connected state -->
		<div class="rounded-2xl border border-slate-100 bg-white p-4 shadow-sm dark:border-white/5 dark:bg-white/5">
			<div class="flex items-center gap-2">
				<div
					class="size-2.5 rounded-full {syncWS.connected ? 'bg-green-500' : 'bg-amber-500'}"
				></div>
				<span class="text-sm font-medium text-slate-700 dark:text-slate-200">
					{syncWS.connected ? 'Verbunden' : 'Verbindung wird hergestellt…'}
				</span>
			</div>

			<div class="mt-3 flex items-center gap-2">
				<code class="min-w-0 flex-1 truncate rounded-lg bg-slate-50 px-3 py-2 text-xs text-slate-600 dark:bg-white/5 dark:text-slate-400">
					{maskedKey(syncKey)}
				</code>
				<button
					type="button"
					onclick={copyKey}
					title="Kopieren"
					aria-label="Kopieren"
					class="shrink-0 rounded-lg bg-slate-100 p-2 text-slate-500 transition-colors hover:bg-slate-200 dark:bg-white/10 dark:text-slate-400 dark:hover:bg-white/15"
				>
					<ContentCopy class="text-[18px]" />
				</button>
			</div>
			<div class="mt-2 flex items-center gap-2">
				<button
					type="button"
					onclick={handleShowQR}
					class="flex flex-1 items-center justify-center gap-1.5 rounded-lg bg-slate-100 px-3 py-2 text-xs font-medium text-slate-600 transition-colors hover:bg-slate-200 dark:bg-white/10 dark:text-slate-300 dark:hover:bg-white/15"
				>
					<QrCode class="text-[16px]" />
					QR-Code
				</button>
				<button
					type="button"
					onclick={downloadKey}
					class="flex flex-1 items-center justify-center gap-1.5 rounded-lg bg-slate-100 px-3 py-2 text-xs font-medium text-slate-600 transition-colors hover:bg-slate-200 dark:bg-white/10 dark:text-slate-300 dark:hover:bg-white/15"
				>
					<Download class="text-[16px]" />
					Als Datei
				</button>
			</div>

			<p class="mt-2 text-xs text-slate-400 dark:text-slate-500">
				Letzte Synchronisierung: {formatTimestamp(lastSync)}
			</p>

			<div class="mt-4 flex gap-2">
				<button
					onclick={manualSync}
					disabled={syncing}
					class="flex flex-1 items-center justify-center gap-2 rounded-xl bg-primary px-4 py-2.5 text-sm font-bold text-white shadow-sm transition-colors hover:bg-primary/90 disabled:opacity-50"
				>
					<Sync class="text-[18px] {syncing ? 'animate-spin' : ''}" />
					{syncing ? 'Synchronisiere…' : 'Sync jetzt'}
				</button>
				<button
					onclick={disconnect}
					class="rounded-xl border border-red-200 px-4 py-2.5 text-sm font-medium text-red-600 transition-colors hover:bg-red-50"
				>
					Trennen
				</button>
			</div>
		</div>

		<!-- Link to another device -->
		<div class="rounded-2xl border border-slate-100 bg-white p-4 shadow-sm dark:border-white/5 dark:bg-white/5">
			<p class="text-sm font-medium text-slate-700 dark:text-slate-200">Auf anderem Gerät einrichten</p>
			<p class="mt-1 text-xs text-slate-400 dark:text-slate-500">
				Kopiere den Schlüssel und füge ihn auf dem anderen Gerät ein.
			</p>
		</div>
	{:else}
		<!-- Not connected state -->
		<div class="rounded-2xl border border-slate-100 bg-white p-4 shadow-sm dark:border-white/5 dark:bg-white/5">
			<p class="text-sm font-medium text-slate-700 dark:text-slate-200">Neuen Sync starten</p>
			<p class="mt-1 text-xs text-slate-400 dark:text-slate-500">
				Erstelle einen Schlüssel für dieses Gerät.
			</p>
			<button
				onclick={() => (showSyncInfo = true)}
				class="mt-3 flex w-full items-center justify-center gap-2 rounded-xl bg-primary px-4 py-2.5 text-sm font-bold text-white shadow-sm transition-colors hover:bg-primary/90"
			>
				<VpnKey class="text-[18px]" />
				Schlüssel generieren
			</button>
		</div>

		<div class="rounded-2xl border border-slate-100 bg-white p-4 shadow-sm dark:border-white/5 dark:bg-white/5">
			<p class="text-sm font-medium text-slate-700 dark:text-slate-200">Vorhandenen Schlüssel eingeben</p>
			<p class="mt-1 text-xs text-slate-400 dark:text-slate-500">
				Wenn du bereits einen Schlüssel auf einem anderen Gerät hast.
			</p>
			<div class="mt-3 flex gap-2">
				<input
					type="text"
					bind:value={inputKey}
					placeholder="Sync-Schlüssel einfügen"
					class="flex-1 rounded-xl border border-slate-200 bg-slate-50 px-3 py-2.5 text-sm text-slate-700 placeholder:text-slate-300 focus:border-primary focus:outline-none dark:border-white/10 dark:bg-white/5 dark:text-slate-200 dark:placeholder:text-slate-600"
				/>
				<button
					onclick={linkKey}
					disabled={!inputKey.trim()}
					class="rounded-xl bg-primary px-4 py-2.5 text-sm font-bold text-white shadow-sm transition-colors hover:bg-primary/90 disabled:opacity-50"
				>
					Verknüpfen
				</button>
			</div>
		</div>
	{/if}

	<!-- Notifications -->
	<div>
		<p class="text-[11px] font-bold uppercase tracking-wider text-primary">Benachrichtigungen</p>
		<p class="mt-1 text-sm text-slate-500 dark:text-slate-400">
			Erinnerung, wenn dein Streak droht zu brechen.
		</p>
	</div>
	<div class="rounded-2xl border border-slate-100 bg-white p-4 shadow-sm dark:border-white/5 dark:bg-white/5">
		{#if !pushStore.supported}
			<div class="flex items-center gap-2">
				<div class="size-2.5 rounded-full bg-slate-300 dark:bg-slate-600"></div>
				<span class="text-sm font-medium text-slate-700 dark:text-slate-200">Nicht verf&uuml;gbar</span>
			</div>
			<p class="mt-2 text-xs text-slate-400 dark:text-slate-500">
				Dein Browser unterst&uuml;tzt keine Push-Benachrichtigungen.
				{#if /iPhone|iPad/.test(navigator.userAgent) && !('standalone' in navigator)}
					F&uuml;ge die App zum Home-Bildschirm hinzu, um Benachrichtigungen zu aktivieren.
				{/if}
			</p>
		{:else if pushStore.permission === 'denied'}
			<div class="flex items-center gap-2">
				<div class="size-2.5 rounded-full bg-red-400"></div>
				<span class="text-sm font-medium text-slate-700 dark:text-slate-200">Blockiert</span>
			</div>
			<p class="mt-2 text-xs text-slate-400 dark:text-slate-500">
				Benachrichtigungen wurden im Browser blockiert. &Auml;ndere die Einstellung in den Browser-/Systemeinstellungen.
			</p>
		{:else}
			<div class="flex items-center justify-between">
				<div class="flex items-center gap-2">
					{#if pushStore.subscribed}
						<div class="size-2.5 rounded-full bg-green-500"></div>
					{:else}
						<div class="size-2.5 rounded-full bg-slate-300 dark:bg-slate-600"></div>
					{/if}
					<span class="text-sm font-medium text-slate-700 dark:text-slate-200">Streak-Erinnerung</span>
				</div>
				<button
					onclick={() => (pushStore.subscribed ? pushStore.disable() : pushStore.enable())}
					class="relative inline-flex h-6 w-11 shrink-0 cursor-pointer rounded-full transition-colors duration-200 {pushStore.subscribed
						? 'bg-primary'
						: 'bg-slate-200 dark:bg-white/10'}"
					role="switch"
					aria-checked={pushStore.subscribed}
					aria-label="Streak-Erinnerung aktivieren"
				>
					<span
						class="pointer-events-none inline-block size-5 rounded-full bg-white shadow-sm ring-0 transition-transform duration-200 {pushStore.subscribed
							? 'translate-x-5'
							: 'translate-x-0.5'} mt-0.5"
					></span>
				</button>
			</div>
			<p class="mt-2 text-xs text-slate-400 dark:text-slate-500">
				{pushStore.subscribed
					? 'Du erh\u00e4ltst eine Erinnerung, wenn du l\u00e4nger als 20 Stunden nicht ge\u00fcbt hast.'
					: 'Aktiviere, um t\u00e4glich erinnert zu werden, bevor dein Streak bricht.'}
			</p>
		{/if}
	</div>

	<!-- About link -->
	<a
		href="/about"
		class="flex items-center justify-between rounded-2xl border border-slate-100 bg-white p-4 shadow-sm transition-colors hover:bg-slate-50 dark:border-white/5 dark:bg-white/5 dark:hover:bg-white/10"
	>
		<div>
			<p class="text-sm font-medium text-slate-700 dark:text-slate-200">Über Taijobi</p>
			<p class="mt-0.5 text-xs text-slate-400 dark:text-slate-500">FAQ, Datenschutz, Tech Stack</p>
		</div>
		<svg class="size-4 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
			<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
		</svg>
	</a>
</div>

<!-- Sync-Info-Sheet — explains what enabling sync actually does before
     generating a key. Cribbed from wimg's pattern; the key generation is
     irreversible from a sync-Worker perspective (the key is identity), so
     we show the implications first. -->
<Drawer open={showSyncInfo} onclose={() => (showSyncInfo = false)}>
	{#snippet children({ handle, content, footer })}
		<div {@attach handle} class="flex justify-center pt-3 pb-2">
			<div class="h-1 w-10 rounded-full bg-slate-200 dark:bg-white/10"></div>
		</div>

		<div {@attach content} class="px-6">
			<div class="mb-5 flex items-center gap-3">
				<div class="flex size-12 shrink-0 items-center justify-center rounded-2xl bg-primary/10">
					<Sync class="text-primary" />
				</div>
				<div>
					<h3 class="text-lg font-extrabold text-slate-900 dark:text-slate-100">Sync</h3>
					<p class="text-sm text-slate-500 dark:text-slate-400">Daten zwischen Ger&auml;ten teilen</p>
				</div>
			</div>

			<div class="space-y-3">
				<div class="flex items-start gap-3">
					<div class="mt-0.5 flex size-8 shrink-0 items-center justify-center rounded-xl bg-emerald-50 dark:bg-emerald-500/10">
						<svg class="size-4 text-emerald-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
						</svg>
					</div>
					<div>
						<p class="text-sm font-medium text-slate-900 dark:text-slate-100">
							Echtzeit-Synchronisierung
						</p>
						<p class="text-xs text-slate-500 dark:text-slate-400">
							Karten, Lexikon und Reviews erscheinen sofort auf allen verbundenen Ger&auml;ten.
						</p>
					</div>
				</div>

				<div class="flex items-start gap-3">
					<div class="mt-0.5 flex size-8 shrink-0 items-center justify-center rounded-xl bg-emerald-50 dark:bg-emerald-500/10">
						<svg class="size-4 text-emerald-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
						</svg>
					</div>
					<div>
						<p class="text-sm font-medium text-slate-900 dark:text-slate-100">
							Ein Schl&uuml;ssel, kein Konto
						</p>
						<p class="text-xs text-slate-500 dark:text-slate-400">
							Ein zuf&auml;lliger Sync-Schl&uuml;ssel wird erstellt. Kein Konto, kein Passwort, keine E-Mail.
						</p>
					</div>
				</div>

				<div class="flex items-start gap-3">
					<div class="mt-0.5 flex size-8 shrink-0 items-center justify-center rounded-xl bg-red-50 dark:bg-red-500/10">
						<VpnKey class="text-[14px] text-red-500" />
					</div>
					<div>
						<p class="text-sm font-medium text-slate-900 dark:text-slate-100">
							Schl&uuml;ssel geheim halten
						</p>
						<p class="text-xs text-slate-500 dark:text-slate-400">
							Wer den Schl&uuml;ssel hat, kann deine Daten sehen. Teile ihn nur mit deinen eigenen Ger&auml;ten.
						</p>
					</div>
				</div>

				<div class="flex items-start gap-3">
					<div class="mt-0.5 flex size-8 shrink-0 items-center justify-center rounded-xl bg-purple-50 dark:bg-purple-500/10">
						<Icon name="smart_toy" class="text-[14px] text-purple-500" />
					</div>
					<div>
						<p class="text-sm font-medium text-slate-900 dark:text-slate-100">
							MCP f&uuml;r KI-Agenten
						</p>
						<p class="text-xs text-slate-500 dark:text-slate-400">
							Der Sync-Schl&uuml;ssel dient auch als MCP-Zugang. Claude Desktop kann
							W&ouml;rter hinzuf&uuml;gen, Kindle-Highlights importieren und Reviews abfragen.
						</p>
					</div>
				</div>
			</div>
		</div>

		<div {@attach footer} class="px-6 pb-8 pt-4">
			<button
				onclick={() => {
					showSyncInfo = false;
					generateKey();
				}}
				class="mb-2 w-full rounded-2xl bg-primary py-3 text-sm font-bold text-white shadow-sm transition-colors hover:bg-primary/90"
			>
				Sync aktivieren
			</button>
			<button
				onclick={() => (showSyncInfo = false)}
				class="w-full rounded-2xl py-3 text-sm font-medium text-slate-500 transition-colors hover:bg-slate-100 dark:text-slate-400 dark:hover:bg-white/5"
			>
				Abbrechen
			</button>
		</div>
	{/snippet}
</Drawer>

<!-- QR-Code-Sheet — encodes /settings?sync=KEY so scanning from another
     device's camera lands directly on Settings with the key pre-filled.
     Also serves as the primary "back this up" affordance, since password
     managers reject our page-set value="..." on iOS / Bitwarden. -->
<Drawer open={showQr} onclose={closeQR}>
	{#snippet children({ handle, content, footer })}
		<div {@attach handle} class="flex justify-center pt-3 pb-2">
			<div class="h-1 w-10 rounded-full bg-slate-200 dark:bg-white/10"></div>
		</div>

		<div {@attach content} class="flex flex-col items-center px-6">
			<h3 class="mb-1 text-lg font-bold text-slate-900 dark:text-slate-100">Sync-Schl&uuml;ssel</h3>
			<p class="mb-6 text-xs text-slate-500 dark:text-slate-400">
				Scanne diesen Code mit deinem Passwort-Manager oder einem anderen Ger&auml;t.
			</p>

			{#if qrSvg}
				<div
					class="size-64 rounded-2xl border border-slate-100 bg-white p-5 shadow-sm dark:border-white/5"
				>
					{@html qrSvg}
				</div>
			{/if}

			<p
				class="mt-5 break-all px-4 text-center font-mono text-xs text-slate-500 dark:text-slate-400"
			>
				{syncKey}
			</p>
		</div>

		<div {@attach footer} class="px-6 pb-8 pt-4">
			<button
				onclick={closeQR}
				class="w-full rounded-2xl bg-primary py-3 text-sm font-bold text-white shadow-sm transition-colors hover:bg-primary/90"
			>
				Fertig
			</button>
		</div>
	{/snippet}
</Drawer>
