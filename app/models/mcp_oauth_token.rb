# Token de acesso do MCP emitido por OAuth. O dono é o usuário do Connect, então
# as ferramentas continuam rodando com as permissões de conta e canal dele.
class McpOauthToken < ApplicationRecord
  LIFETIME = 24.hours

  belongs_to :user

  def self.issue!(client_id:, user:)
    create!(
      token: SecureRandom.hex(32),
      refresh_token: SecureRandom.hex(32),
      client_id: client_id,
      user: user,
      expires_at: LIFETIME.from_now
    )
  end

  def self.authenticate(token)
    find_by(token: token)&.then { |record| record if record.active? }
  end

  def active?
    revoked_at.nil? && expires_at.future?
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  def to_token_response
    {
      access_token: token,
      token_type: 'Bearer',
      expires_in: (expires_at - Time.current).to_i,
      refresh_token: refresh_token
    }
  end
end
