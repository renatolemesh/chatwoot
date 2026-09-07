<script setup>
import { ref, watch, onMounted } from 'vue';
import { formatTime } from '@chatwoot/utils';
import ReportsAPI from 'dashboard/api/reports';
import HelpIcon from './HelpIcon.vue';

const props = defineProps({
  filters: {
    type: Object,
    required: true,
  },
});

const METRIC_KEYS = ['first_response_time', 'resolution_time'];
const PERCENTILE_KEYS = ['p50', 'p90', 'p95'];

const percentiles = ref({});
const isFetching = ref(false);

const fetchPercentiles = () => {
  if (!props.filters.to || !props.filters.from) {
    return;
  }
  isFetching.value = true;
  ReportsAPI.getResponseTimePercentiles(props.filters)
    .then(response => {
      percentiles.value = response.data;
    })
    .finally(() => {
      isFetching.value = false;
    });
};

const displayValue = value => (value === null ? '--' : formatTime(value));

watch(() => props.filters, fetchPercentiles, { deep: true });

onMounted(fetchPercentiles);
</script>

<template>
  <div
    class="px-6 py-5 mt-4 shadow outline-1 outline outline-n-container rounded-xl bg-n-solid-2"
  >
    <h3
      class="flex items-center gap-1 m-0 mb-4 text-sm font-medium text-n-slate-12"
    >
      {{ $t('REPORT.PERCENTILES.HEADER') }}
      <HelpIcon :content="$t('REPORT.PERCENTILES.DESCRIPTION')" />
    </h3>
    <div class="overflow-x-auto">
      <table class="w-full text-sm border-collapse">
        <thead>
          <tr class="text-xs text-left text-n-slate-11">
            <th class="py-2 pe-4 font-medium">
              {{ $t('REPORT.PERCENTILES.METRIC') }}
            </th>
            <th
              v-for="key in PERCENTILE_KEYS"
              :key="key"
              class="py-2 pe-4 font-medium whitespace-nowrap"
            >
              {{ $t(`REPORT.PERCENTILES.${key.toUpperCase()}`) }}
            </th>
            <th class="py-2 font-medium whitespace-nowrap">
              {{ $t('REPORT.PERCENTILES.SAMPLE') }}
            </th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="metric in METRIC_KEYS"
            :key="metric"
            class="border-t border-n-container"
          >
            <td class="py-2 pe-4 text-n-slate-12 whitespace-nowrap">
              {{ $t(`REPORT.PERCENTILES.METRICS.${metric.toUpperCase()}`) }}
            </td>
            <td
              v-for="key in PERCENTILE_KEYS"
              :key="key"
              class="py-2 pe-4 tabular-nums text-n-slate-12 whitespace-nowrap"
            >
              {{ displayValue(percentiles[metric]?.[key] ?? null) }}
            </td>
            <td class="py-2 tabular-nums text-n-slate-11 whitespace-nowrap">
              {{ (percentiles[metric]?.count ?? 0).toLocaleString() }}
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    <p v-if="isFetching" class="mt-3 mb-0 text-xs text-n-slate-10">
      {{ $t('REPORT.LOADING_CHART') }}
    </p>
  </div>
</template>
