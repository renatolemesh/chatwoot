# Código de autorização de uso único, amarrado ao usuário que aprovou, ao cliente
# e ao desafio PKCE. É o que garante que o token emitido carregue a identidade —
# e portanto as permissões — de quem passou pela tela de consentimento.
class McpOauthGrant < ApplicationRecord
  LIFETIME = 10.minutes

  belongs_to :user

  def self.issue!(client_id:, user:, redirect_uri:, code_challenge:)
    create!(
      code: SecureRandom.hex(32),
      client_id: client_id,
      user: user,
      redirect_uri: redirect_uri,
      code_challenge: code_challenge,
      expires_at: LIFETIME.from_now
    )
  end

  def redeemable?(client_id:, redirect_uri:, code_verifier:)
    used_at.nil? && expires_at.future? &&
      self.client_id == client_id && self.redirect_uri == redirect_uri &&
      pkce_valid?(code_verifier)
  end

  def redeem!
    update!(used_at: Time.current)
  end

  private

  def pkce_valid?(code_verifier)
    return false if code_verifier.blank?

    digest = Base64.urlsafe_encode64(Digest::SHA256.digest(code_verifier), padding: false)
    ActiveSupport::SecurityUtils.secure_compare(digest, code_challenge)
  end
end
