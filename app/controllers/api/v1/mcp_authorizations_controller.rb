# Tela de consentimento do MCP: roda com o usuário já autenticado no Connect, o
# que evita pedir a senha de novo e mantém MFA e SSO valendo. O código emitido
# fica preso a este usuário, então o assistente herda exatamente as permissões
# de conta e de canal dele.
class Api::V1::McpAuthorizationsController < Api::BaseController
  before_action :set_client

  def index
    render json: { client_name: @client.client_name }
  end

  def create
    grant = McpOauthGrant.issue!(
      client_id: @client.client_id,
      user: current_user,
      redirect_uri: params[:redirect_uri],
      code_challenge: params[:code_challenge]
    )

    render json: { redirect_uri: callback_url(code: grant.code) }
  end

  private

  def set_client
    @client = McpOauthClient.find_by(client_id: params[:client_id])
    return render json: { error: 'Cliente OAuth desconhecido.' }, status: :not_found if @client.blank?

    render json: { error: 'redirect_uri não registrada.' }, status: :unprocessable_entity unless @client.redirect_uri_allowed?(params[:redirect_uri])
  end

  def callback_url(code:)
    uri = URI.parse(params[:redirect_uri])
    query = Rack::Utils.parse_query(uri.query).merge({ 'code' => code, 'state' => params[:state] }.compact)
    uri.query = query.to_query
    uri.to_s
  end
end
