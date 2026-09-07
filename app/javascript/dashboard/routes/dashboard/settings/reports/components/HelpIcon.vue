<script setup>
defineProps({
  content: {
    type: String,
    required: true,
  },
});
</script>

<template>
  <fluent-icon
    v-tooltip="content"
    size="14"
    icon="info"
    class="flex-shrink-0 text-n-slate-10"
  />
</template>
