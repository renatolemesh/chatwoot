<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import ReportsAPI from 'dashboard/api/reports';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import HelpIcon from './HelpIcon.vue';

const props = defineProps({
  filters: {
    type: Object,
    required: true,
  },
});

const { t } = useI18n();

const reasons = ref(null);

const fetchReasons = () => {
  if (!props.filters.to || !props.filters.from) {
    return;
  }
  ReportsAPI.getResolutionReasons(props.filters)
    .then(response => {
      reasons.value = response.data;
    })
    .catch(() => {
      useAlert(t('REPORT.DATA_FETCHING_FAILED'));
    });
};

const labels = computed(() => reasons.value?.labels ?? []);

const labelledTotal = computed(() => reasons.value?.labelled ?? 0);

const coverageText = computed(() => {
  const total = reasons.value?.total ?? 0;
  const labelled = labelledTotal.value;
  return t('REPORT.RESOLUTION_REASONS.COVERAGE', {
    labelled: labelled.toLocaleString(),
    total: total.toLocaleString(),
    unlabelled: (reasons.value?.unlabelled ?? 0).toLocaleString(),
    share: total ? Math.round((labelled / total) * 100) : 0,
  });
});

const shareOfLabelled = count =>
  labelledTotal.value ? Math.round((count / labelledTotal.value) * 100) : 0;

watch(() => props.filters, fetchReasons, { deep: true });

onMounted(fetchReasons);
</script>

<template>
  <div
    class="px-6 py-5 mt-4 shadow outline-1 outline outline-n-container rounded-xl bg-n-solid-2"
  >
    <h3
      class="flex items-center gap-1 m-0 mb-4 text-sm font-medium text-n-slate-12"
    >
      {{ $t('REPORT.RESOLUTION_REASONS.HEADER') }}
      <HelpIcon :content="$t('REPORT.RESOLUTION_REASONS.DESCRIPTION')" />
    </h3>
    <p
      class="px-3 py-2 mt-0 mb-4 text-xs rounded-md text-n-slate-12 bg-n-solid-3"
    >
      {{ coverageText }}
    </p>

    <div v-if="labels.length" class="overflow-x-auto">
      <table class="w-full text-sm border-collapse">
        <thead>
          <tr class="text-xs text-left text-n-slate-11">
            <th class="py-2 pe-4 font-medium">
              {{ $t('REPORT.RESOLUTION_REASONS.LABEL') }}
            </th>
            <th class="py-2 pe-4 font-medium whitespace-nowrap">
              {{ $t('REPORT.RESOLUTION_REASONS.CLOSURES') }}
            </th>
            <th class="py-2 font-medium whitespace-nowrap">
              {{ $t('REPORT.RESOLUTION_REASONS.SHARE') }}
            </th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="label in labels"
            :key="label.name"
            class="border-t border-n-container"
          >
            <td class="py-2 pe-4 text-n-slate-12">{{ label.name }}</td>
            <td
              class="py-2 pe-4 tabular-nums text-n-slate-12 whitespace-nowrap"
            >
              {{ label.count.toLocaleString() }}
            </td>
            <td class="py-2 tabular-nums text-n-slate-11 whitespace-nowrap">
              {{ shareOfLabelled(label.count) }}%
            </td>
          </tr>
        </tbody>
      </table>
      <p class="mt-3 mb-0 text-xs text-n-slate-10">
        {{ $t('REPORT.RESOLUTION_REASONS.MULTI_LABEL_NOTE') }}
      </p>
    </div>
    <p v-else class="mt-0 mb-0 text-sm text-n-slate-10">
      {{ $t('REPORT.RESOLUTION_REASONS.NO_LABELS') }}
    </p>
  </div>
</template>
