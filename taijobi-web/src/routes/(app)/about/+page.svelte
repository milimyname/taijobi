<script lang="ts">
	import { afterNavigate } from '$app/navigation';
	import { APP_VERSION, RELEASES_URL } from '$lib/version';
	import ArrowBack from '$lib/icons/ArrowBack.svelte';
	import Translate from '$lib/icons/Translate.svelte';

	/**
	 * Convert plain-text FAQ answers into light HTML:
	 * - Lines starting with • become <li> in a <ul>
	 * - Double newlines become paragraph breaks
	 * - Single newlines become <br>
	 * - Text wrapped in backticks becomes <code>
	 * Safe: all FAQ text is hardcoded in this file, not user input.
	 */
	function formatAnswer(text: string): string {
		// Escape HTML entities first
		const escaped = text
			.replace(/&/g, '&amp;')
			.replace(/</g, '&lt;')
			.replace(/>/g, '&gt;');

		// Extract fenced code blocks (```...```) BEFORE other formatting
		// so their content isn't mangled by bullet/paragraph logic.
		const codeBlockClass =
			'my-2 overflow-x-auto rounded-lg bg-slate-50 p-3 font-mono text-xs leading-relaxed text-slate-700 dark:bg-white/5 dark:text-slate-300';
		const withCodeBlocks = escaped.replace(
			/```(\w*)\n?([\s\S]*?)```/g,
			(_, _lang, code) => `<pre class="${codeBlockClass}"><code>${code.trim()}</code></pre>`,
		);

		// Convert inline backtick-wrapped text to <code>
		const withCode = withCodeBlocks.replace(
			/`([^`]+)`/g,
			'<code class="rounded bg-slate-100 px-1 py-0.5 font-mono text-xs text-slate-700 dark:bg-white/10 dark:text-slate-300">$1</code>',
		);

		// Split into paragraphs on double newlines
		const paragraphs = withCode.split(/\n\n+/);

		return paragraphs
			.map((p) => {
				const lines = p.split('\n');
				const bullets = lines.filter((l) => l.startsWith('• '));
				if (bullets.length > 0) {
					// Mix of bullets and non-bullets in one paragraph
					const parts: string[] = [];
					let currentBullets: string[] = [];
					for (const line of lines) {
						if (line.startsWith('• ')) {
							currentBullets.push(`<li class="ml-4">${line.slice(2)}</li>`);
						} else {
							if (currentBullets.length > 0) {
								parts.push(`<ul class="my-2 list-disc space-y-1.5 pl-2">${currentBullets.join('')}</ul>`);
								currentBullets = [];
							}
							if (line.trim()) parts.push(`<p>${line}</p>`);
						}
					}
					if (currentBullets.length > 0) {
						parts.push(`<ul class="my-2 list-disc space-y-1.5 pl-2">${currentBullets.join('')}</ul>`);
					}
					return parts.join('');
				}
				return `<p>${p.replace(/\n/g, '<br>')}</p>`;
			})
			.join('<div class="mt-2"></div>');
	}

	// Scroll to hash anchor and auto-open <details> after navigation completes.
	afterNavigate(() => {
		const hash = window.location.hash;
		if (!hash) return;
		const id = hash.slice(1);

		function scrollToAnchor() {
			if (document.body.style.position === 'fixed') {
				requestAnimationFrame(scrollToAnchor);
				return;
			}
			const el = document.getElementById(id);
			if (!el) return;
			if (el.tagName === 'DETAILS') (el as HTMLDetailsElement).open = true;
			el.scrollIntoView({ behavior: 'smooth', block: 'start' });
		}
		scrollToAnchor();
	});

	const faqs = [
		{
			id: 'faq-was-ist',
			q: 'Was ist Taijobi?',
			a: 'Eine lokale Vokabel-Engine für jede Sprache, der du begegnest. Tiefer Chinesisch-Support, Lehrbuch-Pakete (HSK, Lóng) und Spaced Repetition mit FSRS — alles in einer App. Inspiriert von libghostty: die Bibliothek (libtaijobi in Zig) ist das Produkt, Web und iOS sind dünne Hüllen.',
		},
		{
			id: 'faq-rewrite',
			q: 'Warum wurde Taijobi neu geschrieben?',
			a: 'Das alte Taijobi war ein klassisches Web-Projekt: SvelteKit-Frontend, Supabase/PocketBase als Cloud-DB, Backend-API-Routes für jede Operation, Auth-System mit Konten und Sessions, Docker auf Fly.io, nur Japanisch mit englischer UI, und kein Offline-Modus. 765 Commits, davon das meiste Infrastruktur. Der Rewrite wurde irgendwann komplett zum Stillstand gebracht. Das neue Taijobi dreht das Modell um: libtaijobi (Zig) IST das Produkt, kompiliert zu WASM für Web und zu .a für iOS, alle Logik und SQLite lokal, OPFS statt Cloud-DB, Sync-Schlüssel statt Auth, Cloudflare Pages statt Docker, multi-language statt nur Japanisch, offline-first statt online-only. Die gleiche Architektur wie wimg — bewährt, nicht experimentell — und libhanzi/libtaijobi steht im Mittelpunkt, die UIs sind dünne Hüllen darüber.',
		},
		{
			id: 'faq-fsrs',
			q: 'Was ist FSRS und wie funktioniert das Üben?',
			a: 'FSRS (Free Spaced Repetition Scheduler) ist ein moderner Wiederholungs-Algorithmus, der vorhersagt, wann du eine Karte vergisst. Du bewertest jede Karte mit 1–4 (Nochmal, Schwer, Gut, Einfach), und der Algorithmus plant das nächste Review. Implementiert in reinem Zig — keine Rust-FFI, kein externer Dienst.',
		},
		{
			id: 'faq-sicherheit',
			q: 'Sind meine Daten sicher?',
			a: 'Ja. Alle Karten, Reviews und Pakete liegen in einer lokalen SQLite-Datenbank im OPFS deines Browsers. Sync ist optional und Ende-zu-Ende verschlüsselt mit XChaCha20-Poly1305 — der Server sieht nur Chiffretext.',
		},
		{
			id: 'faq-offline',
			q: 'Funktioniert Taijobi offline?',
			a: 'Ja, vollständig. Taijobi ist eine PWA und kann installiert werden. WASM, alle Wörterbücher (CEDICT, Strichfolge, Zerlegung, Wiktionary EN/DE) und deine Datenbank liegen lokal. Sync ist optional und braucht nur dann Internet, wenn du mehrere Geräte verbinden willst.',
		},
		{
			id: 'faq-pakete',
			q: 'Welche Pakete gibt es?',
			a: 'Eingebaut: HSK 1–6 (3.0) und Lóng neu L5. Außerdem kannst du eigene Pakete per CSV/TSV oder Anki .apkg importieren — Spaltenerkennung läuft heuristisch, du musst nichts manuell zuordnen. Lehrbuch-Pakete leben statisch im Cloudflare-Worker, neue können per PR ergänzt werden.',
		},
		{
			id: 'faq-lexikon',
			q: 'Was ist das persönliche Lexikon?',
			a: 'Wörter, die du beim Lesen sammelst — in jeder Sprache. Tippe ein Wort ein, Taijobi erkennt die Sprache automatisch und reichert chinesische Einträge mit Pinyin und Übersetzung aus CEDICT an. Lexikon-Karten und Paket-Karten landen im selben FSRS-Drill.',
		},
		{
			id: 'faq-wörterbücher',
			q: 'Welche Wörterbücher sind verfügbar?',
			a: 'CC-CEDICT für Chinesisch (124k Einträge), Wiktextract Englisch (166k Einträge) und Wiktextract Deutsch. Plus Strichfolgen-Animation und Radikal-Zerlegung für 9.500 chinesische Zeichen aus Make Me a Hanzi. Wörterbücher werden auf Wunsch installiert (Einstellungen → Wörterbücher), nicht ungefragt heruntergeladen.',
		},
		{
			id: 'faq-zeichen',
			q: 'Was kann die Zeichen-Detailseite?',
			a: 'Tippe auf ein chinesisches Zeichen — überall in der App — um seine Detailseite zu öffnen. Du siehst Pinyin, Definition, Komponenten/Radikale, Strichfolge-Animation und alle Wörter aus deinem Lexikon, in denen das Zeichen vorkommt.',
		},
		{
			id: 'faq-arabisch',
			q: 'Werden auch andere Sprachen unterstützt?',
			a: 'Ja. Sprach-Erkennung läuft per Unicode-Bereichen — Chinesisch, Arabisch (RTL mit Vokalisation), Deutsch, Englisch und mehr. Arabische Karten zeigen Wörter rechts-nach-links mit großer Schrift für die Diakritika. Anki-Imports erkennen die Sprache pro Karte automatisch.',
		},
		{
			id: 'faq-self-assess',
			q: 'Was ist Self-Assessment-Modus?',
			a: 'Bei langen, freitextigen Definitionen (über 50 Zeichen) macht Tippen keinen Sinn — du würdest nie "Das Phänomen einer ungeplanten, glücklichen Entdeckung..." Wort für Wort eingeben. Stattdessen siehst du nur die Frage, klickst "Aufdecken" und bewertest selbst, wie gut du es wusstest.',
		},
		{
			id: 'faq-vorziehen',
			q: 'Was ist „Vorziehen"?',
			a: 'Wenn du alle fälligen Karten geübt hast, bietet Taijobi dir Karten an, die in den nächsten 24 Stunden fällig wären. Reviews zählen normal in FSRS — perfekt für leere Pausen, in denen du noch ein paar Minuten Zeit hast.',
		},
		{
			id: 'faq-sync',
			q: 'Wie synchronisiere ich zwischen Geräten?',
			a: 'Einstellungen → Sync → Schlüssel generieren. Kopiere den Schlüssel und füge ihn auf dem zweiten Gerät ein. Änderungen werden in Echtzeit per WebSocket synchronisiert, Ende-zu-Ende verschlüsselt. Kein Konto, kein Passwort — der Schlüssel ist deine Identität. Ohne Sync funktioniert alles lokal weiter.',
		},
		{
			id: 'faq-mcp',
			q: 'Kann ich Taijobi mit Claude verbinden?',
			a: 'Ja, über einen MCP-Server (Model Context Protocol). Claude Desktop kann dein Taijobi-Lexikon direkt abfragen und ändern.\n\nVerfügbare Tools:\n\n• Fällige Karten anzeigen\n• Wörter zum Lexikon hinzufügen\n• Kindle-Clippings importieren\n• Statistiken und Streak lesen\n• Karten suchen und bewerten\n\nAuthentifizierung läuft über deinen Sync-Schlüssel — die gleiche Ende-zu-Ende-Verschlüsselung wie beim Geräte-Sync.\n\nEinrichtung: Öffne die `claude_desktop_config.json` und füge hinzu:\n\n• macOS: `~/Library/Application Support/Claude/claude_desktop_config.json`\n• Windows: `%APPDATA%\\Claude\\claude_desktop_config.json`\n• Linux: `~/.config/Claude/claude_desktop_config.json`\n\n```json\n{\n  "mcpServers": {\n    "taijobi": {\n      "url": "https://sync.taijobi.com/mcp",\n      "transport": "http",\n      "headers": {\n        "Authorization": "Bearer <dein-sync-schlüssel>"\n      }\n    }\n  }\n}\n```\n\nClaude neustarten — die 8 Tools erscheinen im Tool-Picker.',
		},
		{
			id: 'faq-benachrichtigungen',
			q: 'Benachrichtigungen kommen nicht an — was tun?',
			a: 'Taijobi nutzt Web-Push-Benachrichtigungen. Damit sie ankommen, muss dein Betriebssystem dem Browser bzw. der PWA erlauben, Benachrichtigungen zu senden.\n\nSo aktivierst du es pro Plattform:\n\n• macOS: Systemeinstellungen → Mitteilungen → [Chrome/Safari/Edge] → „Mitteilungen erlauben" aktivieren. Prüfe auch, dass kein Fokus-Modus aktiv ist.\n• iOS (16.4+): Die App muss als PWA installiert sein (Teilen → „Zum Home-Bildschirm"). Danach: Einstellungen → Mitteilungen → Taijobi → erlauben.\n• Windows: Einstellungen → System → Benachrichtigungen → [Chrome/Edge] → Ein.\n• Android: Einstellungen → Apps → [Chrome/Browser] → Benachrichtigungen → erlauben. Oder: lange auf das App-Icon drücken → App-Info → Benachrichtigungen.\n\nWenn alles erlaubt ist und trotzdem nichts kommt:\n\n• Einstellungen → Benachrichtigungen → Streak-Erinnerung aus- und wieder einschalten (setzt das Push-Abo neu).\n• Seite neu laden und Berechtigung erneut erteilen.',
		},
		{
			id: 'faq-shortcuts',
			q: 'Gibt es Tastenkürzel?',
			a: 'Ja. Drücke `?` irgendwo in der App, um die Hilfe zu öffnen.\n\nNavigation (Vim-Style — tippe `g` dann den Buchstaben):\n\n• `g h` — Start\n• `g d` — Üben\n• `g s` — Statistik\n• `g w` — Wörterbuch\n• `g p` — Pakete\n• `g l` — Lexikon\n• `g c` — Zeichen\n• `g e` — Einstellungen\n\nIm Drill:\n\n• `1–4` — Karte bewerten (Nochmal / Schwer / Gut / Einfach)\n• `←` — Vorherige Karte anzeigen\n• `Enter` — Antwort prüfen\n\nGlobal:\n\n• `⌘ K` / `Ctrl+K` — Befehlspalette öffnen',
		},
		{
			id: 'faq-darkmode',
			q: 'Gibt es einen Dark Mode?',
			a: 'Ja. Einstellungen → Erscheinungsbild → Hell/Dunkel/System. Die Wahl wird gespeichert und folgt im System-Modus dem OS-Theme. Vor dem ersten Render läuft ein kleines Inline-Skript, damit es kein Helligkeits-Flackern gibt.',
		},
		{
			id: 'faq-import',
			q: 'Wie importiere ich aus Anki/Quizlet?',
			a: 'Pakete → CSV/TSV-Datei oder Anki-.apkg-Datei ablegen. Taijobi erkennt die Spalten heuristisch (Wort, Pinyin, Übersetzung), erstellt automatisch ein Paket und zeigt eine Vorschau vor dem Import. Bilder und Audio werden in v1 nicht importiert.',
		},
		{
			id: 'faq-export',
			q: 'Kann ich meine Karten exportieren?',
			a: 'Ja. Pakete → „CSV exportieren" lädt eine TSV-Datei mit allen Karten herunter — Wort, Sprache, Pinyin, Übersetzung, Paket, FSRS-Status. Kompatibel mit Anki, Quizlet und jedem Tabellen-Tool.',
		},
		{
			id: 'faq-stats',
			q: 'Was zeigt die Statistik?',
			a: 'Streak und Tagesübersicht oben, dann ein Balkendiagramm der Reviews mit Zeitraum-Toggle, Genauigkeitsverlauf, Bewertungs-Verteilung und ein 365-Tage-Aktivitäts-Heatmap im GitHub-Stil. Alle Daten kommen aus dem lokalen review_log — nichts geht in die Cloud.',
		},
		{
			id: 'faq-kostenlos',
			q: 'Ist Taijobi kostenlos?',
			a: 'Ja. Open-Source-Projekt, keine Abos, kein Tracking, kein Verkauf deiner Daten. Hosting läuft auf Cloudflare Pages und kostet im Praxisalltag nichts.',
		},
		{
			id: 'faq-ios',
			q: 'Gibt es eine iOS-App?',
			a: 'Geplant für Phase 6.1: SwiftUI-Hülle, die libtaijobi.a über das gleiche C-ABI lädt wie das Web. Volle Feature-Parität, weil die gesamte Logik in der Zig-Library steckt. Die Web-PWA funktioniert in der Zwischenzeit problemlos auf iOS.',
		},
		{
			id: 'faq-android',
			q: 'Gibt es eine Android-App?',
			a: 'Aktuell nein — die Web-PWA läuft aber vollständig auf Android und kann über Chrome installiert werden. Ein nativer Android-Build wäre möglich, ist aber nicht in der aktuellen Roadmap.',
		},
		{
			id: 'faq-beitragen',
			q: 'Wie kann ich beitragen?',
			a: 'Besuche das GitHub-Repository. Code, neue Lehrbuch-Pakete (Phase 6.3 plant ein PR-basiertes Marketplace-System unter packs/community/), Übersetzungen, Bug-Reports und Feedback sind willkommen.',
		},
	];
</script>

<section class="space-y-5 py-4">
	<!-- Header -->
	<div class="flex items-center gap-3">
		<a
			href="/more"
			class="flex size-10 items-center justify-center rounded-2xl bg-white shadow-sm dark:bg-white/5"
			aria-label="Zurück"
		>
			<ArrowBack class="text-slate-600 dark:text-slate-300" />
		</a>
		<h2 class="text-2xl font-extrabold text-slate-900 dark:text-slate-100">Über Taijobi</h2>
	</div>

	<!-- Hero card -->
	<div
		class="flex flex-col items-center rounded-3xl border border-slate-100 p-6 text-center dark:border-white/5"
	>
		<div class="mb-4 flex size-16 items-center justify-center rounded-2xl bg-primary">
			<Translate class="text-white" style="font-size: 32px" />
		</div>
		<h3 class="mb-1 text-xl font-extrabold text-slate-900 dark:text-slate-100">Taijobi</h3>
		<p class="text-sm font-medium text-slate-500 dark:text-slate-400">
			Persönliche Vokabel-Engine.<br />Lokal. Privat. Offline.
		</p>
		<p class="mt-3 text-xs text-slate-400 dark:text-slate-500">
			Von <span class="font-semibold">Komiljon Maksudov</span> · Zig + Svelte + SQLite
		</p>
	</div>

	<!-- Quick info grid -->
	<div class="grid grid-cols-2 gap-3">
		<div class="rounded-2xl border border-slate-100 bg-white p-4 dark:border-white/5 dark:bg-white/5">
			<div class="mb-2.5 flex size-9 items-center justify-center rounded-xl bg-primary/10">
				<svg class="size-5 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
				</svg>
			</div>
			<h4 class="mb-0.5 text-sm font-bold text-slate-900 dark:text-slate-100">Privatsphäre</h4>
			<p class="text-xs leading-snug text-slate-500 dark:text-slate-400">
				Kein Tracking. Keine Telemetrie. Niemals.
			</p>
		</div>
		<div class="rounded-2xl border border-slate-100 bg-white p-4 dark:border-white/5 dark:bg-white/5">
			<div class="mb-2.5 flex size-9 items-center justify-center rounded-xl bg-primary/10">
				<svg class="size-5 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4" />
				</svg>
			</div>
			<h4 class="mb-0.5 text-sm font-bold text-slate-900 dark:text-slate-100">Open Source</h4>
			<p class="text-xs leading-snug text-slate-500 dark:text-slate-400">
				Quellcode offen auf GitHub.
			</p>
		</div>
	</div>

	<!-- Privacy details -->
	<div class="space-y-3 rounded-2xl border border-slate-100 bg-white p-5 dark:border-white/5 dark:bg-white/5">
		<h3 class="text-sm font-bold text-slate-900 dark:text-slate-100">Datenschutz im Detail</h3>
		{#each [
			{ icon: '🔒', title: 'Lokal gespeichert', desc: 'SQLite im OPFS deines Browsers. Kein Cloud-Konto nötig.' },
			{ icon: '🔐', title: 'Ende-zu-Ende verschlüsselt', desc: 'Sync nutzt XChaCha20-Poly1305. Der Server sieht nur Chiffretext.' },
			{ icon: '📚', title: 'Wörterbücher embedded', desc: 'CEDICT & Wiktionary laufen lokal in WASM. Keine API-Calls.' },
			{ icon: '🚫', title: 'Kein Tracking', desc: 'Keine Analytics, keine Telemetrie, kein Google.' },
			{ icon: '👤', title: 'Kein Account', desc: 'Kein Passwort, keine E-Mail. Sync-Schlüssel ist die Identität.' },
			{ icon: '⚡', title: 'Library is the product', desc: 'libtaijobi (Zig) trägt die Logik. Web ist nur ein Renderer.' },
		] as item (item.title)}
			<div class="flex items-start gap-3">
				<span class="mt-0.5 text-base leading-none">{item.icon}</span>
				<div>
					<p class="text-xs font-semibold text-slate-900 dark:text-slate-100">{item.title}</p>
					<p class="text-xs leading-snug text-slate-500 dark:text-slate-400">{item.desc}</p>
				</div>
			</div>
		{/each}
	</div>

	<!-- GitHub button -->
	<a
		href="https://github.com/milimyname/taijobi"
		target="_blank"
		rel="noopener noreferrer"
		class="flex w-full items-center justify-center gap-2.5 rounded-2xl bg-slate-900 py-3.5 text-sm font-bold text-white transition-opacity hover:opacity-90 active:scale-[0.98] dark:bg-white dark:text-slate-900"
	>
		<svg class="size-5" fill="currentColor" viewBox="0 0 24 24">
			<path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z" />
		</svg>
		Auf GitHub ansehen
	</a>

	<!-- Tech Stack -->
	<div>
		<h3 class="mb-3 text-lg font-extrabold text-slate-900 dark:text-slate-100">Tech Stack</h3>
		<div class="grid grid-cols-3 gap-2.5">
			{#each [
				{ icon: '⚙️', name: 'libtaijobi', sub: 'Zig + SQLite' },
				{ icon: '🎨', name: 'Web', sub: 'Svelte 5 + Tailwind' },
				{ icon: '📱', name: 'iOS', sub: 'SwiftUI (geplant)' },
			] as t (t.name)}
				<div class="rounded-2xl border border-slate-100 bg-white p-3.5 text-center dark:border-white/5 dark:bg-white/5">
					<div class="mx-auto mb-2 flex size-9 items-center justify-center rounded-xl bg-primary/10">
						<span class="text-lg">{t.icon}</span>
					</div>
					<p class="text-xs font-bold text-slate-900 dark:text-slate-100">{t.name}</p>
					<p class="mt-0.5 text-[10px] text-slate-500 dark:text-slate-400">{t.sub}</p>
				</div>
			{/each}
		</div>
	</div>

	<!-- Datenschutz callout -->
	<div class="rounded-2xl border border-dashed border-primary/30 bg-primary/5 p-5">
		<div class="mb-2.5 flex items-center gap-2">
			<svg class="size-5 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24">
				<path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
			</svg>
			<h3 class="text-base font-extrabold text-slate-900 dark:text-slate-100">Datenschutz</h3>
		</div>
		<ul class="space-y-1.5 text-xs leading-relaxed text-slate-500 dark:text-slate-400">
			<li class="flex gap-2">
				<span class="shrink-0 text-primary">✓</span>
				Alle Daten bleiben auf deinem Gerät (OPFS / lokale Datei)
			</li>
			<li class="flex gap-2">
				<span class="shrink-0 text-primary">✓</span>
				Sync ist optional und Ende-zu-Ende verschlüsselt
			</li>
			<li class="flex gap-2">
				<span class="shrink-0 text-primary">✓</span>
				Keine Konten, keine Passwörter, kein Tracking
			</li>
			<li class="flex gap-2">
				<span class="shrink-0 text-primary">✓</span>
				Wörterbücher laufen offline in WASM
			</li>
		</ul>
	</div>

	<!-- FAQ -->
	<div id="faq">
		<h3 class="mb-3 flex items-center gap-2 text-lg font-extrabold text-slate-900 dark:text-slate-100">
			<svg class="size-5 text-amber-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
				<path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
			</svg>
			Häufig gestellte Fragen
		</h3>

		<div class="space-y-2">
			{#each faqs as faq (faq.id)}
				<details
					id={faq.id}
					class="group overflow-hidden rounded-2xl border border-slate-100 bg-white dark:border-white/5 dark:bg-white/5"
				>
					<summary class="flex cursor-pointer list-none select-none items-center justify-between p-4">
						<span class="pr-4 text-sm font-semibold text-slate-900 dark:text-slate-100">{faq.q}</span>
						<svg
							class="size-4 shrink-0 text-slate-400 transition-transform group-open:rotate-180"
							fill="none"
							stroke="currentColor"
							viewBox="0 0 24 24"
						>
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
						</svg>
					</summary>
					<div class="faq-answer px-4 pb-4 text-sm leading-relaxed text-slate-500 dark:text-slate-400">
						{@html formatAnswer(faq.a)}
					</div>
				</details>
			{/each}
		</div>
	</div>

	<!-- Footer -->
	<footer class="flex flex-col items-center gap-2 pb-6 pt-2 text-slate-400 dark:text-slate-500">
		<a href={RELEASES_URL} target="_blank" rel="noopener noreferrer" class="text-xs font-bold text-primary hover:underline">
			Was ist neu?
		</a>
		<span class="font-mono text-xs opacity-50">v{APP_VERSION}</span>
	</footer>
</section>

<style>
	summary::-webkit-details-marker,
	summary::marker {
		display: none;
	}
</style>
