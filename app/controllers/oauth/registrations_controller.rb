# Registro dinâmico de cliente (RFC 7591). O ChatGPT e o Claude chamam este
# endpoint sozinhos na primeira conexão para obter um client_id.
class Oauth::RegistrationsController < ActionController::API
  def create
    uris = Array(params[:redirect_uris]).map(&:to_s).select { |uri| valid_redirect_uri?(uri) }
    return render json: registration_error, status: :bad_request if uris.empty?

    client = McpOauthClient.register!(name: params[:client_name], redirect_uris: uris)
    render json: client.metadata, status: :created
  end

  private

  # Só HTTPS, com exceção do localhost usado por clientes de desktop.
  def valid_redirect_uri?(uri)
    parsed = URI.parse(uri)
    parsed.scheme == 'https' || (parsed.scheme == 'http' && ['localhost', '127.0.0.1'].include?(parsed.host))
  rescue URI::InvalidURIError
    false
  end

  def registration_error
    {
      error: 'invalid_redirect_uri',
      error_description: 'Informe ao menos uma redirect_uri HTTPS.'
    }
  end
end
