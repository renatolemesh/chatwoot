# Início do fluxo de autorização. Não dá para saber aqui quem está logado — o
# Connect autentica por devise_token_auth, sem cookie de sessão —, então esta
# ação só valida o pedido e entrega a decisão à tela do próprio Connect, que já
# roda com o usuário autenticado.
class Oauth::AuthorizationsController < ActionController::API
  include Oauth::BaseUrl

  def new
    client = McpOauthClient.find_by(client_id: params[:client_id])
    return render_invalid('Cliente OAuth desconhecido.') if client.blank?
    return render_invalid('redirect_uri não registrada para este cliente.') unless client.redirect_uri_allowed?(params[:redirect_uri])
    return render_invalid('Apenas response_type=code e code_challenge_method=S256 são aceitos.') unless supported_request?

    redirect_to consent_url, allow_other_host: true
  end

  private

  def supported_request?
    params[:response_type] == 'code' &&
      params[:code_challenge].present? &&
      params[:code_challenge_method].to_s.upcase == 'S256'
  end

  # Os parâmetros seguem para a tela e voltam na aprovação, onde são validados de
  # novo contra o cliente registrado. Adulterá-los no caminho não ajuda: o código
  # nasce preso ao usuário autenticado e à redirect_uri conferida.
  def consent_url
    query = {
      client_id: params[:client_id],
      redirect_uri: params[:redirect_uri],
      code_challenge: params[:code_challenge],
      state: params[:state]
    }.compact.to_query

    "#{base_url}/app/oauth/consent?#{query}"
  end

  # Um pedido inválido nunca pode ser devolvido por redirecionamento: a
  # redirect_uri é justamente o que não foi possível confiar.
  def render_invalid(message)
    render plain: "Pedido de autorização inválido: #{message}", status: :bad_request
  end
end
