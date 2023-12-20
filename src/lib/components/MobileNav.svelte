<script lang="ts">
	import { fly } from 'svelte/transition';
	import { sineIn } from 'svelte/easing';
	import { showAppNav, showNav } from '$lib/utils/stores';
	import { clickOutside } from '$lib/utils/clickOutside';
	import { HelpCircle, CreditCard, CircleUser, Dices, LogOut, GraduationCap } from 'lucide-svelte';
</script>

{#if $showNav}
	<div
		use:clickOutside={() => {
			$showNav = false;
			$showAppNav = false;
		}}
		class="fixed bottom-5 z-30 w-full p-5 sm:bottom-10 lg:bottom-5"
		transition:fly={{
			delay: 0,
			duration: 500,
			opacity: 0,
			y: 50,
			easing: sineIn
		}}
	>
		<div class="-mb-52 h-17 w-full rounded-4xl border-4 border-[#bddffa] bg-white shadow-xl">
			<a
				href="/"
				class="flex justify-between p-4"
				on:click={() => {
					$showAppNav = false;
					$showNav = false;
				}}
			>
				<HelpCircle />
				<h4 class="text-xl font-medium">Taijobi</h4>
			</a>
		</div>
		<div class="-mb-36 h-52 w-full rounded-4xl border-4 border-[#82c5f7] bg-white shadow-xl">
			<a
				href="/"
				class="flex justify-between p-4"
				on:click={() => {
					$showAppNav = false;
					$showNav = false;
				}}
			>
				<CreditCard />
				<h4 class="text-xl font-medium">Pricing</h4>
			</a>
		</div>
		<div class="-mb-20 h-36 w-full rounded-4xl border-4 border-[#40a8f0] bg-white shadow-xl">
			<a
				href="/profile"
				class="flex justify-between p-4"
				on:click={() => {
					$showAppNav = false;
					$showNav = false;
				}}
			>
				<CircleUser />
				<h4 class="text-xl font-medium">Profile</h4>
			</a>
		</div>
	</div>
{:else if $showAppNav}
	<div
		use:clickOutside={() => {
			$showNav = false;
			$showAppNav = false;
		}}
		class="fixed bottom-20 z-30 w-full p-5"
		transition:fly={{
			delay: 0,
			duration: 500,
			opacity: 0,
			y: 50,
			easing: sineIn
		}}
	>
		<div class="-mb-52 h-17 w-full rounded-4xl border-4 border-[#F86F03] bg-white shadow-xl">
			<a
				href="/quizzes"
				class="flex justify-between p-4"
				on:click={() => {
					$showAppNav = false;
					$showNav = false;
				}}
			>
				<GraduationCap />
				<h4 class="text-xl font-medium">Studying</h4>
			</a>
		</div>
		<div class="-mb-36 h-52 w-full rounded-4xl border-4 border-[#8294C4] bg-white shadow-xl">
			<a
				href="/"
				class="flex justify-between p-4"
				on:click={() => {
					$showAppNav = false;
					$showNav = false;
				}}
			>
				<Dices />
				<h4 class="text-xl font-medium">Quizzes</h4>
			</a>
		</div>
		<div class="-mb-20 h-36 w-full rounded-4xl border-4 border-[#47A992] bg-white shadow-xl">
			<form action="/logout" method="POST">
				<button type="submit" class="flex w-full justify-between p-4">
					<LogOut class="h-6 w-6" />
					<h4 class="text-xl font-medium">Log out</h4>
				</button>
			</form>
		</div>
	</div>
{/if}
