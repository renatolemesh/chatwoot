/* global axios */
import ApiClient from './ApiClient';

const getTimeOffset = () => -new Date().getTimezoneOffset() / 60;

class ReportsAPI extends ApiClient {
  constructor() {
    super('reports', { accountScoped: true, apiVersion: 'v2' });
  }

  getReports({
    metric,
    from,
    to,
    type = 'account',
    id,
    groupBy,
    businessHours,
  }) {
    return axios.get(`${this.url}`, {
      params: {
        metric,
        since: from,
        until: to,
        type,
        id,
        group_by: groupBy,
        business_hours: businessHours,
        timezone_offset: getTimeOffset(),
      },
    });
  }

  // eslint-disable-next-line default-param-last
  getSummary(since, until, type = 'account', id, groupBy, businessHours) {
    return axios.get(`${this.url}/summary`, {
      params: {
        since,
        until,
        type,
        id,
        group_by: groupBy,
        business_hours: businessHours,
        timezone_offset: getTimeOffset(),
      },
    });
  }

  getConversationMetric(type = 'account', page = 1) {
    return axios.get(`${this.url}/conversations`, {
      params: {
        type,
        page,
      },
    });
  }

  getAgentReports({ from: since, to: until, businessHours }) {
    return axios.get(`${this.url}/agents`, {
      params: { since, until, business_hours: businessHours },
    });
  }

  getConversationsSummaryReports({ from: since, to: until, businessHours }) {
    return axios.get(`${this.url}/conversations_summary`, {
      params: { since, until, business_hours: businessHours },
    });
  }

  getConversationTrafficCSV({ daysBefore = 6 } = {}) {
    return axios.get(`${this.url}/conversation_traffic`, {
      params: { timezone_offset: getTimeOffset(), days_before: daysBefore },
    });
  }

  getLabelReports({ from: since, to: until, businessHours }) {
    return axios.get(`${this.url}/labels`, {
      params: { since, until, business_hours: businessHours },
    });
  }

  getInboxReports({ from: since, to: until, businessHours }) {
    return axios.get(`${this.url}/inboxes`, {
      params: { since, until, business_hours: businessHours },
    });
  }

  getTeamReports({ from: since, to: until, businessHours }) {
    return axios.get(`${this.url}/teams`, {
      params: { since, until, business_hours: businessHours },
    });
  }

  getBotMetrics({ from, to } = {}) {
    return axios.get(`${this.url}/bot_metrics`, {
      params: { since: from, until: to },
    });
  }

  getResponseTimePercentiles({ from, to, businessHours } = {}) {
    return axios.get(`${this.url}/response_time_percentiles`, {
      params: {
        since: from,
        until: to,
        business_hours: businessHours,
      },
    });
  }

  getConversationBacklog({ from, to } = {}) {
    return axios.get(`${this.url}/conversation_backlog`, {
      params: {
        since: from,
        until: to,
        timezone_offset: getTimeOffset(),
      },
    });
  }

  getConversationFunnel({ from, to } = {}) {
    return axios.get(`${this.url}/conversation_funnel`, {
      params: { since: from, until: to },
    });
  }

  getResolutionReasons({ from, to } = {}) {
    return axios.get(`${this.url}/resolution_reasons`, {
      params: { since: from, until: to },
    });
  }

  getInboxStatusBreakdown({ from, to } = {}) {
    return axios.get(`${this.url}/inbox_status_breakdown`, {
      params: { since: from, until: to },
    });
  }

  getInboxLabelMatrix({ from, to } = {}) {
    return axios.get(`${this.url}/inbox_label_matrix`, {
      params: { since: from, until: to },
    });
  }

  getBotSummary({ from, to, groupBy, businessHours } = {}) {
    return axios.get(`${this.url}/bot_summary`, {
      params: {
        since: from,
        until: to,
        type: 'account',
        group_by: groupBy,
        business_hours: businessHours,
      },
    });
  }
}

export default new ReportsAPI();
