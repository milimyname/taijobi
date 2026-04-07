<script lang="ts">
	import Add from './Add.svelte';
	import AddCircle from './AddCircle.svelte';
	import ArrowBack from './ArrowBack.svelte';
	import AutoStories from './AutoStories.svelte';
	import BarChart from './BarChart.svelte';
	import Book from './Book.svelte';
	import Book2 from './Book2.svelte';
	import Cancel from './Cancel.svelte';
	import Check from './Check.svelte';
	import CheckCircle from './CheckCircle.svelte';
	import ChevronRight from './ChevronRight.svelte';
	import Close from './Close.svelte';
	import CloudOff from './CloudOff.svelte';
	import ContentCopy from './ContentCopy.svelte';
	import Contrast from './Contrast.svelte';
	import DarkMode from './DarkMode.svelte';
	import Delete from './Delete.svelte';
	import Dictionary from './Dictionary.svelte';
	import Download from './Download.svelte';
	import DownloadDone from './DownloadDone.svelte';
	import Draw from './Draw.svelte';
	import Edit from './Edit.svelte';
	import Explore from './Explore.svelte';
	import ExpandMore from './ExpandMore.svelte';
	import FastForward from './FastForward.svelte';
	import FolderOpen from './FolderOpen.svelte';
	import Home from './Home.svelte';
	import HourglassEmpty from './HourglassEmpty.svelte';
	import Inventory2 from './Inventory2.svelte';
	import Language from './Language.svelte';
	import LightMode from './LightMode.svelte';
	import LocalFireDepartment from './LocalFireDepartment.svelte';
	import Mic from './Mic.svelte';
	import Person from './Person.svelte';
	import PhotoCamera from './PhotoCamera.svelte';
	import PlayArrow from './PlayArrow.svelte';
	import PlayCircle from './PlayCircle.svelte';
	import Search from './Search.svelte';
	import SearchOff from './SearchOff.svelte';
	import Settings from './Settings.svelte';
	import Shuffle from './Shuffle.svelte';
	import Style from './Style.svelte';
	import SwapVert from './SwapVert.svelte';
	import Sync from './Sync.svelte';
	import Today from './Today.svelte';
	import Translate from './Translate.svelte';
	import Upload from './Upload.svelte';
	import UploadFile from './UploadFile.svelte';
	import VolumeUp from './VolumeUp.svelte';
	import VpnKey from './VpnKey.svelte';

	const map: Record<string, typeof Add> = {
		add: Add,
		add_circle: AddCircle,
		arrow_back: ArrowBack,
		auto_stories: AutoStories,
		bar_chart: BarChart,
		book: Book,
		book_2: Book2,
		cancel: Cancel,
		check: Check,
		check_circle: CheckCircle,
		chevron_right: ChevronRight,
		close: Close,
		cloud_off: CloudOff,
		content_copy: ContentCopy,
		contrast: Contrast,
		dark_mode: DarkMode,
		delete: Delete,
		dictionary: Dictionary,
		download: Download,
		download_done: DownloadDone,
		draw: Draw,
		edit: Edit,
		expand_more: ExpandMore,
		explore: Explore,
		fast_forward: FastForward,
		folder_open: FolderOpen,
		home: Home,
		hourglass_empty: HourglassEmpty,
		inventory_2: Inventory2,
		language: Language,
		light_mode: LightMode,
		local_fire_department: LocalFireDepartment,
		mic: Mic,
		person: Person,
		photo_camera: PhotoCamera,
		play_arrow: PlayArrow,
		play_circle: PlayCircle,
		search: Search,
		search_off: SearchOff,
		settings: Settings,
		shuffle: Shuffle,
		style: Style,
		swap_vert: SwapVert,
		sync: Sync,
		today: Today,
		translate: Translate,
		upload: Upload,
		upload_file: UploadFile,
		volume_up: VolumeUp,
		vpn_key: VpnKey,
	};

	let { name, class: className = '' }: { name: string; class?: string } = $props();
	const Cmp = $derived(map[name]);
</script>

{#if Cmp}
	<Cmp class={className} />
{/if}
