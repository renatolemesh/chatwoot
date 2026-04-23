<script setup>
import { computed, ref } from 'vue';
import { useStore } from 'dashboard/composables/store';
import BaseBubble from './Base.vue';
import { useI18n } from 'vue-i18n';
import { CONTENT_TYPES, MESSAGE_TYPES } from '../constants.js';
import { useMessageContext } from '../provider.js';
import { useInbox } from 'dashboard/composables/useInbox';
import { useAlert } from 'dashboard/composables';

const { content, contentAttributes, contentType, conversationId, messageType } =
  useMessageContext();
const { t } = useI18n();
const { isAWebWidgetInbox } = useInbox();
const store = useStore();

const formattedContent = computed(() => {
  return (content.value || '').replace(/\n/g, '<br>');
});

const submittedValues = computed(
  () => contentAttributes.value?.submittedValues ?? []
);

const selectItems = computed(() => {
  if (contentType.value !== CONTENT_TYPES.INPUT_SELECT) return [];
  const items = contentAttributes.value?.items ?? [];
  return items
    .filter(item => item && item.title)
    .map(item => ({ title: item.title, value: item.value ?? item.title }));
});

const isInteractiveSelect = computed(
  () =>
    contentType.value === CONTENT_TYPES.INPUT_SELECT &&
    messageType.value === MESSAGE_TYPES.INCOMING &&
    submittedValues.value.length === 0 &&
    selectItems.value.length > 0
);

const formValues = computed(() => {
  if (contentType.value === CONTENT_TYPES.FORM) {
    const { items, submittedValues: submitted = [] } = contentAttributes.value;

    if (submitted.length) {
      return submitted.map(submittedValue => {
        const item = items.find(
          formItem => formItem.name === submittedValue.name
        );
        return {
          title: submittedValue.value,
          value: submittedValue.value,
          label: item?.label,
        };
      });
    }

    return [];
  }

  if (contentType.value === CONTENT_TYPES.INPUT_SELECT) {
    const [item] = submittedValues.value;
    if (!item) return [];

    return [
      {
        title: item.title,
        value: item.value,
        label: '',
      },
    ];
  }

  return [];
});

const sentItem = ref(null);
const isSending = ref(false);

const onSelectItem = async item => {
  if (isSending.value || sentItem.value) return;
  isSending.value = true;
  try {
    await store.dispatch('createPendingMessageAndSend', {
      conversationId: conversationId.value,
      message: item.title,
    });
    sentItem.value = item.value;
  } catch (error) {
    const errorMessage =
      error?.response?.data?.error || t('CONVERSATION.MESSAGE_ERROR');
    useAlert(errorMessage);
  } finally {
    isSending.value = false;
  }
};
</script>

<template>
  <BaseBubble class="px-4 py-3" data-bubble-name="csat">
    <span v-dompurify-html="formattedContent" :title="content" />

    <div v-if="isInteractiveSelect" class="mt-3 flex flex-col gap-2">
      <button
        v-for="item in selectItems"
        :key="item.value"
        type="button"
        :disabled="isSending || !!sentItem"
        class="w-full rounded-md border border-n-strong bg-n-background px-3 py-2 text-n-slate-12 text-sm font-medium transition-colors hover:bg-n-solid-2 disabled:cursor-not-allowed disabled:opacity-60"
        @click="onSelectItem(item)"
      >
        {{ item.title }}
      </button>
    </div>

    <dl v-if="formValues.length" class="mt-4">
      <template v-for="item in formValues" :key="item.title">
        <dt class="text-n-slate-11 italic mt-2">
          {{ item.label || t('CONVERSATION.RESPONSE') }}
        </dt>
        <dd>{{ item.title }}</dd>
      </template>
    </dl>

    <div
      v-else-if="!isInteractiveSelect && isAWebWidgetInbox"
      class="my-2 font-medium"
    >
      {{ t('CONVERSATION.NO_RESPONSE') }}
    </div>
  </BaseBubble>
</template>
