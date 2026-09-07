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

const STATUS_KEYS = ['open', 'pending', 'snoozed', 'resolved'];

const inboxes = ref([]);

const fetchInboxes = () => {
  if (!props.filters.to || !props.filters.from) {
    return;
  }
  ReportsAPI.getInboxStatusBreakdown(props.filters)
    .then(response => {
      inboxes.value = response.data;
    })
    .catch(() => {
      useAlert(t('REPORT.DATA_FETCHING_FAILED'));
    });
};

// The API returns the class name, e.g. "Channel::Whatsapp".
const channelName = channelType => (channelType || '').replace('Channel::', '');

const rows = computed(() =>
  inboxes.value.map(inbox => ({
    ...inbox,
    channelName: channelName(inbox.channel_type),
  }))
);

watch(() => props.filters, fetchInboxes, { deep: true });

onMounted(fetchInboxes);
</script>

<template>
  <div
    class="px-6 py-5 mt-4 shadow outline-1 outline outline-n-container rounded-xl bg-n-solid-2"
  >
    <h3
      class="flex items-center gap-1 m-0 mb-4 text-sm font-medium text-n-slate-12"
    >
      {{ $t('REPORT.INBOX_STATUS.HEADER') }}
      <HelpIcon :content="$t('REPORT.INBOX_STATUS.DESCRIPTION')" />
    </h3>
    <div v-if="rows.length" class="overflow-x-auto">
      <table class="w-full text-sm border-collapse">
        <thead>
          <tr class="text-xs text-left text-n-slate-11">
            <th class="py-2 pe-4 font-medium">
              {{ $t('REPORT.INBOX_STATUS.INBOX') }}
            </th>
            <th class="py-2 pe-4 font-medium">
              {{ $t('REPORT.INBOX_STATUS.CHANNEL') }}
            </th>
            <th
              v-for="status in STATUS_KEYS"
              :key="status"
              class="py-2 pe-4 font-medium whitespace-nowrap"
            >
              {{ $t(`REPORT.INBOX_STATUS.STATUS.${status.toUpperCase()}`) }}
            </th>
            <th class="py-2 font-medium whitespace-nowrap">
              {{ $t('REPORT.INBOX_STATUS.TOTAL') }}
            </th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="row in rows"
            :key="row.id"
            class="border-t border-n-container"
          >
            <td class="py-2 pe-4 text-n-slate-12">
              {{ row.name }}
            </td>
            <td class="py-2 pe-4 text-n-slate-10 whitespace-nowrap">
              {{ row.channelName }}
            </td>
            <td
              v-for="status in STATUS_KEYS"
              :key="status"
              class="py-2 pe-4 tabular-nums text-n-slate-11 whitespace-nowrap"
            >
              {{ row[status].toLocaleString() }}
            </td>
            <td
              class="py-2 font-medium tabular-nums text-n-slate-12 whitespace-nowrap"
            >
              {{ row.total.toLocaleString() }}
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    <p v-else class="mt-0 mb-0 text-sm text-n-slate-10">
      {{ $t('REPORT.INBOX_STATUS.EMPTY') }}
    </p>
  </div>
</template>
