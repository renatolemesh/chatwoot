<script>
import { useAlert } from 'dashboard/composables';
import EmojiOrIcon from 'shared/components/EmojiOrIcon.vue';
import { copyTextToClipboard } from 'shared/helpers/clipboard';
import NextButton from 'dashboard/components-next/button/Button.vue';

export default {
  components: {
    EmojiOrIcon,
    NextButton,
  },
  props: {
    href: {
      type: String,
      default: '',
    },
    icon: {
      type: String,
      required: true,
    },
    emoji: {
      type: String,
      required: true,
    },
    value: {
      type: String,
      default: '',
    },
    showCopy: {
      type: Boolean,
      default: false,
    },
  },
  methods: {
    async onCopy(e) {
      e.preventDefault();
      await copyTextToClipboard(this.value);
      useAlert(this.$t('CONTACT_PANEL.COPY_SUCCESSFUL'));
    },
    formatPhoneNumber(phone) {
      let digits = phone.replace(/\D/g, '');

      if (digits.length === 13) {
        // +55 DDD 9 XXXX-XXXX → remove DDI(2) + DDD(2) + 9
        digits = digits.slice(4);
        if (digits.length === 9) digits = digits.slice(1);
      } else if (digits.length === 12) {
        // +55 DDD XXXX-XXXX → remove DDI(2) + DDD(2)
        digits = digits.slice(4);
      } else if (digits.length === 11) {
        // DDD 9 XXXX-XXXX → remove DDD(2) + 9
        digits = digits.slice(2);
        if (digits.length === 9) digits = digits.slice(1);
      } else if (digits.length === 10) {
        // DDD XXXX-XXXX → remove DDD(2)
        digits = digits.slice(2);
      } else if (digits.length === 9) {
        // 9 XXXX-XXXX → remove 9
        digits = digits.slice(1);
      }

      if (digits.length === 8) {
        return `${digits.slice(0, 4)}-${digits.slice(4)}`;
      }
      return digits;
    },
    async onCopyFormatted(e) {
      e.preventDefault();
      const formatted = this.formatPhoneNumber(this.value);
      await copyTextToClipboard(formatted);
      useAlert(this.$t('CONTACT_PANEL.COPY_SUCCESSFUL'));
    },
  },
};
</script>

<template>
  <div class="w-full h-5 ltr:-ml-1 rtl:-mr-1">
    <a
      v-if="href"
      :href="href"
      class="flex items-center gap-2 text-n-slate-11 hover:underline"
    >
      <EmojiOrIcon
        :icon="icon"
        :emoji="emoji"
        icon-size="14"
        class="flex-shrink-0 ltr:ml-1 rtl:mr-1"
      />
      <span
        v-if="value"
        class="overflow-hidden text-sm whitespace-nowrap text-ellipsis"
        :title="value"
      >
        {{ value }}
      </span>
      <span v-else class="text-sm text-n-slate-11">
        {{ $t('CONTACT_PANEL.NOT_AVAILABLE') }}
      </span>
      <NextButton
        v-if="showCopy"
        ghost
        xs
        slate
        class="ltr:-ml-1 rtl:-mr-1"
        icon="i-lucide-clipboard"
        @click="onCopy"
      />
      <NextButton
        v-if="showCopy"
        ghost
        xs
        slate
        class="ltr:-ml-1 rtl:-mr-1"
        icon="i-lucide-brush"
        title="Copiar formatado (xxxx-xxxx)"
        @click="onCopyFormatted"
      />
    </a>

    <div v-else class="flex items-center gap-2 text-n-slate-11">
      <EmojiOrIcon
        :icon="icon"
        :emoji="emoji"
        icon-size="14"
        class="flex-shrink-0 ltr:ml-1 rtl:mr-1"
      />
      <span
        v-if="value"
        v-dompurify-html="value"
        class="overflow-hidden text-sm whitespace-nowrap text-ellipsis"
      />
      <span v-else class="text-sm text-n-slate-11">
        {{ $t('CONTACT_PANEL.NOT_AVAILABLE') }}
      </span>
    </div>
  </div>
</template>
