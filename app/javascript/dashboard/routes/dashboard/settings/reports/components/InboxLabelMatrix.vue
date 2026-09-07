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

const data = ref({ inboxes: [], labels: [], matrix: [] });

const fetchMatrix = () => {
  if (!props.filters.to || !props.filters.from) {
    return;
  }
  ReportsAPI.getInboxLabelMatrix(props.filters)
    .then(response => {
      data.value = response.data;
    })
    .catch(() => {
      useAlert(t('REPORT.DATA_FETCHING_FAILED'));
    });
};

// A label that never appears, or an inbox that carries none, is a column or row of
// zeroes. Dropping them is what keeps a 11x36 grid readable.
const visible = computed(() => {
  const { inboxes = [], labels = [], matrix = [] } = data.value;
  const labelIndexes = labels
    .map((label, index) => index)
    .filter(index => matrix.some(row => row[index] > 0));
  const rowIndexes = inboxes
    .map((inbox, index) => index)
    .filter(index => labelIndexes.some(column => matrix[index][column] > 0));

  return {
    labels: labelIndexes.map(index => labels[index]),
    rows: rowIndexes.map(index => ({
      inbox: inboxes[index],
      counts: labelIndexes.map(column => matrix[index][column]),
    })),
  };
});

watch(() => props.filters, fetchMatrix, { deep: true });

onMounted(fetchMatrix);
</script>

<template>
  <div
    class="px-6 py-5 mt-4 shadow outline-1 outline outline-n-container rounded-xl bg-n-solid-2"
  >
    <h3
      class="flex items-center gap-1 m-0 mb-4 text-sm font-medium text-n-slate-12"
    >
      {{ $t('REPORT.MATRIX.HEADER') }}
      <HelpIcon :content="$t('REPORT.MATRIX.DESCRIPTION')" />
    </h3>
    <div v-if="visible.rows.length" class="overflow-x-auto">
      <table class="text-sm border-collapse">
        <thead>
          <tr class="text-xs text-left text-n-slate-11">
            <th class="py-2 pe-4 font-medium whitespace-nowrap">
              {{ $t('REPORT.MATRIX.INBOX') }}
            </th>
            <th
              v-for="label in visible.labels"
              :key="label.id"
              class="py-2 pe-4 font-medium whitespace-nowrap"
            >
              {{ label.title }}
            </th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="row in visible.rows"
            :key="row.inbox.id"
            class="border-t border-n-container"
          >
            <td class="py-2 pe-4 text-n-slate-12 whitespace-nowrap">
              {{ row.inbox.name }}
            </td>
            <td
              v-for="(count, index) in row.counts"
              :key="index"
              class="py-2 pe-4 tabular-nums whitespace-nowrap"
              :class="count ? 'text-n-slate-12' : 'text-n-slate-10'"
            >
              {{ count ? count.toLocaleString() : '--' }}
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    <p v-else class="mt-0 mb-0 text-sm text-n-slate-10">
      {{ $t('REPORT.MATRIX.EMPTY') }}
    </p>
  </div>
</template>
