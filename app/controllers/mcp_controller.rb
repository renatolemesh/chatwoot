# Endpoint do servidor MCP (Streamable HTTP) consumido por assistentes externos,
# como o ChatGPT. Autentica pelo AccessToken do usuário do Connect, de modo que
# todas as ferramentas rodam com as permissões de conta e de canal desse usuário.
class McpController < ActionController::API
  include RequestExceptionHandler
  include Oauth::BaseUrl

  around_action :reset_current_attributes
  before_action :ensure_mcp_enabled
  before_action :authenticate_mcp_user!

  def handle
    return head :no_content if request.delete?
    return head :method_not_allowed unless request.post?
    return render_mcp(parse_error_response) if payload.nil?

    result = Mcp::Server.new(user: @mcp_user, payload: payload).perform
    return head :accepted if result.nil?

    render_mcp(result)
  end

  private

  def reset_current_attributes
    yield
  ensure
    Current.reset
  end

  def ensure_mcp_enabled
    return if ActiveModel::Type::Boolean.new.cast(ENV.fetch('ENABLE_MCP_SERVER', 'true'))

    render json: { error: 'MCP server disabled' }, status: :not_found
  end

  def authenticate_mcp_user!
    @mcp_user = resolve_user_from_token
    return if @mcp_user.present?

    response.headers['WWW-Authenticate'] = unauthorized_challenge
    render json: { error: 'Invalid access token' }, status: :unauthorized
  end

  # Aceita o token emitido por OAuth e também o token pessoal da API, que segue
  # valendo para quem prefere configurar o conector à mão.
  def resolve_user_from_token
    return if mcp_token.blank?

    McpOauthToken.authenticate(mcp_token)&.user || personal_access_token_user
  end

  def personal_access_token_user
    owner = AccessToken.find_by(token: mcp_token)&.owner
    owner if owner.is_a?(User)
  end

  # Sem esta dica o cliente recebe apenas um 401 e não tem como descobrir onde
  # fazer o login (RFC 9728).
  def unauthorized_challenge
    %(Bearer realm="Connect MCP", resource_metadata="#{base_url}/.well-known/oauth-protected-resource")
  end

  def mcp_token
    @mcp_token ||= bearer_token.presence || params[:token].presence || request.headers['api_access_token'].presence
  end

  def bearer_token
    request.headers['Authorization'].to_s[/\ABearer\s+(.+)\z/i, 1].to_s.strip
  end

  def payload
    return @payload if defined?(@payload)

    body = request.body.read
    @payload = body.present? ? JSON.parse(body) : {}
  rescue JSON::ParserError
    @payload = nil
  end

  def parse_error_response
    { 'jsonrpc' => '2.0', 'id' => nil, 'error' => { 'code' => -32_700, 'message' => 'JSON inválido.' } }
  end

  # O ChatGPT e o SDK MCP aceitam tanto JSON puro quanto um evento SSE na resposta
  # do POST. Só usamos SSE quando o cliente não aceita application/json.
  def render_mcp(result)
    if sse_only_client?
      response.headers['Content-Type'] = 'text/event-stream'
      render plain: "event: message\ndata: #{result.to_json}\n\n"
    else
      render json: result
    end
  end

  def sse_only_client?
    accept = request.headers['Accept'].to_s
    accept.include?('text/event-stream') && accept.exclude?('application/json')
  end
end
