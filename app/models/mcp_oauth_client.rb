# Cliente OAuth registrado dinamicamente (RFC 7591). O ChatGPT e o Claude se
# cadastram sozinhos na primeira conexão; não guardamos segredo porque são
# clientes públicos e a segurança vem do PKCE.
class McpOauthClient < ApplicationRecord
  validates :client_id, presence: true, uniqueness: true

  def self.register!(name:, redirect_uris:)
    create!(client_id: SecureRandom.uuid, client_name: name.presence || 'Cliente MCP', redirect_uris: redirect_uris)
  end

  def redirect_uri_allowed?(uri)
    redirect_uris.include?(uri)
  end

  def metadata
    {
      client_id: client_id,
      client_name: client_name,
      redirect_uris: redirect_uris,
      token_endpoint_auth_method: 'none',
      grant_types: %w[authorization_code refresh_token],
      response_types: ['code'],
      client_id_issued_at: created_at.to_i
    }
  end
end
