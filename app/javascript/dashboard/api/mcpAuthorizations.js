/* global axios */
import ApiClient from './ApiClient';

class McpAuthorizations extends ApiClient {
  constructor() {
    super('mcp_authorizations', { accountScoped: false });
  }

  client(params) {
    return axios.get(this.url, { params });
  }

  approve(params) {
    return axios.post(this.url, params);
  }
}

export default new McpAuthorizations();
