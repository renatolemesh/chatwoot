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

const STAGE_KEYS = ['received', 'answered', 'resolved', 'rated'];
const GAP_KEYS = ['unanswered', 'resolved_without_answer'];

const funnel = ref(null);

const fetchFunnel = () => {
  if (!props.filters.to || !props.filters.from) {
    return;
  }
  ReportsAPI.getConversationFunnel(props.filters)
    .then(response => {
      funnel.value = response.data;
    })
    .catch(() => {
      useAlert(t('REPORT.DATA_FETCHING_FAILED'));
    });
};

const received = computed(() => funnel.value?.received ?? 0);

const shareOfReceived = value =>
  received.value ? Math.round((value / received.value) * 100) : 0;

// The first stage is the denominator of every share below it, so its own share
// is always 100% and says nothing. It keeps the full bar as the visual baseline,
// but not the redundant percentage.
const stages = computed(() =>
  STAGE_KEYS.map((key, index) => {
    const value = funnel.value?.[key] ?? 0;
    return {
      key,
      value,
      label: t(`REPORT.FUNNEL.STAGES.${key.toUpperCase()}`),
      share: shareOfReceived(value),
      isBaseline: index === 0,
    };
  })
);

const gaps = computed(() =>
  GAP_KEYS.map(key => {
    const value = funnel.value?.[key] ?? 0;
    return {
      key,
      value,
      label: t(`REPORT.FUNNEL.${key.toUpperCase()}`),
      share: shareOfReceived(value),
    };
  })
);

watch(() => props.filters, fetchFunnel, { deep: true });

onMounted(fetchFunnel);
</script>

<template>
  <div
    class="px-6 py-5 mt-4 shadow outline-1 outline outline-n-container rounded-xl bg-n-solid-2"
  >
    <h3
      class="flex items-center gap-1 m-0 mb-4 text-sm font-medium text-n-slate-12"
    >
      {{ $t('REPORT.FUNNEL.HEADER') }}
      <HelpIcon :content="$t('REPORT.FUNNEL.DESCRIPTION')" />
    </h3>

    <div class="flex flex-col gap-3">
      <div v-for="stage in stages" :key="stage.key" class="flex flex-col gap-1">
        <div class="flex items-baseline justify-between gap-4">
          <span class="text-sm text-n-slate-12">{{ stage.label }}</span>
          <span class="text-sm tabular-nums text-n-slate-11 whitespace-nowrap">
            {{ stage.value.toLocaleString() }}
            <span v-if="!stage.isBaseline" class="text-xs text-n-slate-10">
              {{ stage.share }}% {{ $t('REPORT.FUNNEL.OF_RECEIVED') }}
            </span>
          </span>
        </div>
        <div class="w-full h-2 rounded-full bg-n-slate-3">
          <div
            class="h-2 rounded-full bg-n-brand"
            :style="{ width: `${Math.min(stage.share, 100)}%` }"
          />
        </div>
      </div>
    </div>

    <div class="flex flex-wrap gap-6 pt-4 mt-4 border-t border-n-container">
      <div v-for="gap in gaps" :key="gap.key" class="flex flex-col">
        <span class="text-xs text-n-slate-11">{{ gap.label }}</span>
        <span class="text-lg font-medium tabular-nums text-n-ruby-10">
          {{ gap.value.toLocaleString() }}
          <span class="text-xs font-normal text-n-slate-10">
            {{ gap.share }}% {{ $t('REPORT.FUNNEL.OF_RECEIVED') }}
          </span>
        </span>
      </div>
    </div>
  </div>
</template>
