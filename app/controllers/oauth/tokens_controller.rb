# Troca do código de autorização (ou do refresh token) pelo token de acesso do
# MCP. O token carrega o usuário que aprovou, e é dele que saem as permissões.
class Oauth::TokensController < ActionController::API
  def create
    case params[:grant_type]
    when 'authorization_code' then exchange_code
    when 'refresh_token' then refresh
    else render_error('unsupported_grant_type', 'grant_type não suportado.')
    end
  end

  private

  def exchange_code
    grant = McpOauthGrant.find_by(code: params[:code])
    return render_error('invalid_grant', 'Código inválido, expirado ou já usado.') unless redeemable?(grant)

    grant.redeem!
    issue_for(grant.client_id, grant.user)
  end

  def redeemable?(grant)
    grant.present? && grant.redeemable?(
      client_id: params[:client_id],
      redirect_uri: params[:redirect_uri],
      code_verifier: params[:code_verifier]
    )
  end

  def refresh
    previous = McpOauthToken.find_by(refresh_token: params[:refresh_token], client_id: params[:client_id])
    return render_error('invalid_grant', 'Refresh token inválido ou revogado.') if previous.blank? || previous.revoked_at.present?

    previous.revoke!
    issue_for(previous.client_id, previous.user)
  end

  def issue_for(client_id, user)
    token = McpOauthToken.issue!(client_id: client_id, user: user)
    render json: token.to_token_response.merge(scope: Oauth::BaseUrl::SCOPE)
  end

  def render_error(code, description)
    render json: { error: code, error_description: description }, status: :bad_request
  end
end
