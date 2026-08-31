<script setup>
import { computed, onMounted, ref } from 'vue';
import { useRoute } from 'vue-router';
import { useMapGetter } from 'dashboard/composables/store';
import McpAuthorizations from 'dashboard/api/mcpAuthorizations';
import NextButton from 'dashboard/components-next/button/Button.vue';

const route = useRoute();
const currentUser = useMapGetter('getCurrentUser');

const clientName = ref('');
const hasError = ref(false);
const isSubmitting = ref(false);

const query = computed(() => ({
  client_id: route.query.client_id,
  redirect_uri: route.query.redirect_uri,
  code_challenge: route.query.code_challenge,
  state: route.query.state,
}));

// O pedido volta ao assistente pela própria redirect_uri, tanto na aprovação
// quanto na recusa, que é o que o padrão OAuth espera.
const denialUrl = computed(() => {
  const url = new URL(query.value.redirect_uri);
  url.searchParams.set('error', 'access_denied');
  if (query.value.state) url.searchParams.set('state', query.value.state);
  return url.toString();
});

onMounted(async () => {
  try {
    const { data } = await McpAuthorizations.client({
      client_id: query.value.client_id,
      redirect_uri: query.value.redirect_uri,
    });
    clientName.value = data.client_name;
  } catch {
    hasError.value = true;
  }
});

const authorize = async () => {
  isSubmitting.value = true;
  try {
    const { data } = await McpAuthorizations.approve(query.value);
    window.location.assign(data.redirect_uri);
  } catch {
    hasError.value = true;
    isSubmitting.value = false;
  }
};

const deny = () => window.location.assign(denialUrl.value);
</script>

<template>
  <div class="flex items-center justify-center w-full h-full bg-n-slate-2">
    <div
      class="flex flex-col w-full max-w-md gap-6 p-8 rounded-xl bg-n-solid-1 shadow"
    >
      <template v-if="hasError">
        <p class="text-sm text-n-slate-11">{{ $t('MCP_OAUTH.ERROR') }}</p>
      </template>
      <template v-else>
        <h1 class="text-xl font-medium text-n-slate-12">
          {{ $t('MCP_OAUTH.TITLE') }}
        </h1>
        <p class="text-sm leading-relaxed text-n-slate-11">
          {{
            $t('MCP_OAUTH.DESCRIPTION', {
              client: clientName,
              name: currentUser.name,
            })
          }}
        </p>
        <div class="flex justify-end gap-2">
          <NextButton
            variant="smooth"
            color-scheme="secondary"
            :label="$t('MCP_OAUTH.CANCEL')"
            @click="deny"
          />
          <NextButton
            :is-loading="isSubmitting"
            :label="$t('MCP_OAUTH.AUTHORIZE')"
            @click="authorize"
          />
        </div>
      </template>
    </div>
  </div>
</template>
