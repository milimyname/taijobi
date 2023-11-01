<script lang="ts">
	import { months } from '$lib/utils/constants.js';
	import ApexCharts from 'apexcharts';
	import type { ApexOptions } from 'apexcharts';
	import { onMount } from 'svelte';

	let chart: ApexCharts;
	export let data;

	// Filter months that have data
	const validMonths = months.filter((month) => data.completions[month]);
	const completions = validMonths.map((month) => data.completions[month]);

	const options: ApexOptions = {
		chart: {
			type: 'bar',
			toolbar: {
				tools: {
					download: false,
					selection: false,
					zoom: false,
					zoomin: false,
					zoomout: false
				}
			}
		},
		series: [
			{
				name: 'Quiz Completions',
				data: completions
			}
		],
		yaxis: {
			labels: {
				formatter: (val: number): string => Math.round(val).toString()
			}
		},
		xaxis: {
			categories: validMonths
		}
	};

	onMount(() => {
		chart = new ApexCharts(document.querySelector('#chart'), options);
		chart.render();
	});
</script>

<section class="flex w-full flex-col items-center">
	<div>
		<h1 class="text-lg font-bold sm:text-4xl">Quiz Completions</h1>
		<p style="text-wrap: balance;">
			This quiz shows how many quizzes r completed during a year unless they r deleted
		</p>
	</div>
	<div id="chart" class="w-full lg:w-1/2" />
</section>
