<script lang="ts">
	import ApexCharts from 'apexcharts';
	import type { ApexOptions } from 'apexcharts';
	import { onMount } from 'svelte';

	let chart: ApexCharts;

	const options: ApexOptions = {
		chart: {
			type: 'line'
		},
		series: [
			{
				name: 'sales',
				data: [30, 40, 35, 50, 49, 60, 70, 91, 125]
			}
		],
		xaxis: {
			categories: [1991, 1992, 1993, 1994, 1995, 1996, 1997, 1998, 1999]
		},
	};

	onMount(() => {
		chart = new ApexCharts(document.querySelector('#chart'), options);

		chart.render();
	});
</script>

<div id="chart" />
