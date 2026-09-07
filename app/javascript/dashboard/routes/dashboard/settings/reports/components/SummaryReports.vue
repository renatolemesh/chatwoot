<script setup>
import OverviewReportFilters from './OverviewReportFilters.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import { formatTime } from '@chatwoot/utils';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import Table from 'dashboard/components/table/Table.vue';
import { generateFileName } from 'dashboard/helper/downloadHelper';
import {
  useVueTable,
  createColumnHelper,
  getCoreRowModel,
  getSortedRowModel,
} from '@tanstack/vue-table';
import { computed, onMounted, ref, h } from 'vue';

const props = defineProps({
  type: {
    type: String,
    default: 'account',
  },
  getterKey: {
    type: String,
    default: '',
  },
  actionKey: {
    type: String,
    default: '',
  },
  summaryKey: {
    type: String,
    default: '',
  },
  fetchItemsKey: {
    type: String,
    required: true,
  },
});

const store = useStore();

const from = ref(0);
const to = ref(0);
const businessHours = ref(false);
import { useI18n } from 'vue-i18n';
import SummaryReportLink from './SummaryReportLink.vue';
import HelpIcon from './HelpIcon.vue';
import EntityComparison from './EntityComparison.vue';

const flagMap = {
  agent: 'isFetchingAgentSummaryReports',
  inbox: 'isFetchingInboxSummaryReports',
  team: 'isFetchingTeamSummaryReports',
  label: 'isFetchingLabelSummaryReports',
};

const uiFlags = useMapGetter('summaryReports/getUIFlags');
const isLoading = computed(() => uiFlags.value[flagMap[props.type]] ?? false);

const rowItems = useMapGetter([props.getterKey]) || [];
const reportMetrics = useMapGetter([props.summaryKey]) || [];

const getMetrics = id =>
  reportMetrics.value.find(metrics => metrics.id === Number(id)) || {};
const columnHelper = createColumnHelper();
const { t } = useI18n();

// The row keeps raw numbers so sorting compares values, not formatted strings;
// formatting happens here, at render time.
const renderMetricCell = format => cellProps => {
  const value = cellProps.getValue();
  return h('span', value === undefined ? '--' : format(value));
};

const renderTime = renderMetricCell(formatTime);
const renderCount = renderMetricCell(value => value.toLocaleString());

// Ranking a team means asking who is highest, so metrics open descending; rows
// with no data stay at the bottom either way.
const METRIC_COLUMN_SORTING = { sortDescFirst: true, sortUndefined: 'last' };

// The header cell toggles sorting on click, so the help icon has to swallow its own.
const renderHeader = (labelKey, helpKey) => () =>
  h('span', { class: 'flex items-center gap-1' }, [
    t(labelKey),
    h(HelpIcon, {
      content: t(helpKey),
      onClick: event => event.stopPropagation(),
    }),
  ]);

const columns = computed(() => [
  columnHelper.accessor('name', {
    header: t(`SUMMARY_REPORTS.${props.type.toUpperCase()}`),
    width: 300,
    cell: cellProps => h(SummaryReportLink, cellProps),
  }),
  columnHelper.accessor('conversationsCount', {
    header: renderHeader(
      'SUMMARY_REPORTS.CONVERSATIONS',
      'SUMMARY_REPORTS.HELP.CONVERSATIONS'
    ),
    width: 200,
    cell: renderCount,
    ...METRIC_COLUMN_SORTING,
  }),
  columnHelper.accessor('avgFirstResponseTime', {
    header: renderHeader(
      'SUMMARY_REPORTS.AVG_FIRST_RESPONSE_TIME',
      'SUMMARY_REPORTS.HELP.AVG_FIRST_RESPONSE_TIME'
    ),
    width: 200,
    cell: renderTime,
    ...METRIC_COLUMN_SORTING,
  }),
  columnHelper.accessor('avgResolutionTime', {
    header: renderHeader(
      'SUMMARY_REPORTS.AVG_RESOLUTION_TIME',
      'SUMMARY_REPORTS.HELP.AVG_RESOLUTION_TIME'
    ),
    width: 200,
    cell: renderTime,
    ...METRIC_COLUMN_SORTING,
  }),
  columnHelper.accessor('avgReplyTime', {
    header: renderHeader(
      'SUMMARY_REPORTS.AVG_REPLY_TIME',
      'SUMMARY_REPORTS.HELP.AVG_REPLY_TIME'
    ),
    width: 200,
    cell: renderTime,
    ...METRIC_COLUMN_SORTING,
  }),
  columnHelper.accessor('resolutionsCount', {
    header: renderHeader(
      'SUMMARY_REPORTS.RESOLUTION_COUNT',
      'SUMMARY_REPORTS.HELP.RESOLUTION_COUNT'
    ),
    width: 200,
    cell: renderCount,
    ...METRIC_COLUMN_SORTING,
  }),
]);

const tableData = computed(() =>
  rowItems.value.map(row => {
    const rowMetrics = getMetrics(row.id);
    const {
      conversationsCount,
      avgFirstResponseTime,
      avgResolutionTime,
      avgReplyTime,
      resolvedConversationsCount,
    } = rowMetrics;
    return {
      id: row.id,
      // we fallback on title, label for instance does not have a name property
      name: row.name ?? row.title,
      type: props.type,
      conversationsCount: conversationsCount || undefined,
      avgFirstResponseTime: avgFirstResponseTime || undefined,
      avgReplyTime: avgReplyTime || undefined,
      avgResolutionTime: avgResolutionTime || undefined,
      resolutionsCount: resolvedConversationsCount || undefined,
    };
  })
);

const fetchReportsWithRetry = async () => {
  const params = {
    since: from.value,
    until: to.value,
    businessHours: businessHours.value,
  };
  try {
    await store.dispatch(props.actionKey, params);
  } catch {
    try {
      await store.dispatch(props.actionKey, params);
    } catch {
      useAlert(t('REPORT.SUMMARY_FETCHING_FAILED'));
    }
  }
};

const fetchAllData = () => {
  store.dispatch(props.fetchItemsKey);
  fetchReportsWithRetry();
};

onMounted(() => fetchAllData());

const onFilterChange = updatedFilter => {
  from.value = updatedFilter.from;
  to.value = updatedFilter.to;
  businessHours.value = updatedFilter.businessHours;
  fetchAllData();
};

const sorting = ref([]);

const table = useVueTable({
  get data() {
    return tableData.value;
  },
  get columns() {
    return columns.value;
  },
  state: {
    get sorting() {
      return sorting.value;
    },
  },
  onSortingChange: updater => {
    sorting.value =
      typeof updater === 'function' ? updater(sorting.value) : updater;
  },
  getCoreRowModel: getCoreRowModel(),
  getSortedRowModel: getSortedRowModel(),
});

// downloadReports method is not used in this component
// but it is exposed to be used in the parent component
const downloadReports = () => {
  const dispatchMethods = {
    agent: 'downloadAgentReports',
    label: 'downloadLabelReports',
    inbox: 'downloadInboxReports',
    team: 'downloadTeamReports',
  };
  if (dispatchMethods[props.type]) {
    const fileName = generateFileName({
      type: props.type,
      to: to.value,
      businessHours: businessHours.value,
    });
    const params = {
      from: from.value,
      to: to.value,
      fileName,
      businessHours: businessHours.value,
    };
    store.dispatch(dispatchMethods[props.type], params);
  }
};

defineExpose({ downloadReports });
</script>

<template>
  <OverviewReportFilters
    :disabled="isLoading"
    @filter-change="onFilterChange"
  />
  <div
    class="relative flex-1 overflow-auto px-2 py-2 mt-5 shadow outline-1 outline outline-n-container rounded-xl bg-n-solid-2"
  >
    <Table :table="table" />
    <Transition
      enter-active-class="transition-opacity duration-300 ease-out"
      leave-active-class="transition-opacity duration-200 ease-in"
      enter-from-class="opacity-0"
      enter-to-class="opacity-100"
      leave-from-class="opacity-100"
      leave-to-class="opacity-0"
    >
      <div
        v-if="isLoading"
        class="absolute inset-0 flex justify-center pt-[12.5rem] bg-n-solid-1/70 rounded-xl pointer-events-none"
      >
        <Spinner :size="32" class="text-n-brand" />
      </div>
    </Transition>
  </div>
  <EntityComparison
    :type="type"
    :items="rowItems"
    :filters="{ from, to, businessHours }"
  />
</template>
