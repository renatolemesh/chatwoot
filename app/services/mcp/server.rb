# Implementa o protocolo MCP (JSON-RPC 2.0 sobre HTTP) para clientes externos
# como o ChatGPT. Cada chamada de ferramenta é executada com as permissões do
# usuário dono do token e registrada em McpRequestLog.
class Mcp::Server
  LATEST_PROTOCOL_VERSION = '2025-06-18'.freeze
  SUPPORTED_PROTOCOL_VERSIONS = [LATEST_PROTOCOL_VERSION, '2025-03-26', '2024-11-05'].freeze

  # Respostas fixas do protocolo: o Connect não expõe resources nem prompts, só ferramentas.
  STATIC_RESULTS = {
    'ping' => {},
    'resources/list' => { 'resources' => [] },
    'resources/templates/list' => { 'resourceTemplates' => [] },
    'prompts/list' => { 'prompts' => [] }
  }.freeze

  INSTRUCTIONS = <<~TEXT.freeze
    Servidor MCP do Connect (atendimento omnichannel). Use listar_conversas para ver as conversas
    de um canal (por exemplo "Comercial"), ler_conversa para o histórico completo, buscar_contato
    para localizar uma pessoa e enviar_mensagem para responder. Sempre mostre o texto ao usuário e
    peça confirmação antes de chamar enviar_mensagem.
  TEXT

  def initialize(user:, payload:)
    @user = user
    @payload = payload
  end

  def perform
    return error_response(nil, -32_600, 'Requisição JSON-RPC inválida.') unless payload.is_a?(Hash)
    return nil if method_name.to_s.start_with?('notifications/')

    dispatch
  end

  private

  attr_reader :user, :payload

  def id
    payload['id']
  end

  def method_name
    payload['method']
  end

  def rpc_params
    payload['params'] || {}
  end

  def dispatch
    case method_name
    when 'initialize' then success(initialize_result)
    when 'tools/list' then success({ 'tools' => Mcp::Registry.schemas })
    when 'tools/call' then success(call_tool)
    else static_result
    end
  end

  def static_result
    result = STATIC_RESULTS[method_name]
    return error_response(id, -32_601, "Método não suportado: #{method_name}") if result.nil?

    success(result)
  end

  def initialize_result
    {
      'protocolVersion' => negotiated_protocol_version,
      'capabilities' => { 'tools' => { 'listChanged' => false } },
      'serverInfo' => { 'name' => 'connect-mcp', 'title' => "#{installation_name} MCP", 'version' => Mcp::Registry::VERSION },
      'instructions' => INSTRUCTIONS
    }
  end

  def negotiated_protocol_version
    requested = rpc_params['protocolVersion']
    SUPPORTED_PROTOCOL_VERSIONS.include?(requested) ? requested : LATEST_PROTOCOL_VERSION
  end

  def installation_name
    ENV.fetch('INSTALLATION_NAME', 'Connect')
  end

  def call_tool
    tool_name = rpc_params['name']
    tool_arguments = rpc_params['arguments'] || {}
    tool_class = Mcp::Registry.fetch(tool_name)
    return tool_error("Ferramenta desconhecida: #{tool_name}") if tool_class.blank?

    execute(tool_class, tool_name, tool_arguments)
  end

  def execute(tool_class, tool_name, tool_arguments)
    started_at = Time.current
    data = tool_class.new(user: user, arguments: tool_arguments).perform
    log(tool_name, tool_arguments, 'success', nil, started_at)
    tool_result(data)
  rescue Mcp::Error, ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid, Pundit::NotAuthorizedError => e
    log(tool_name, tool_arguments, 'error', e.message, started_at)
    tool_error(e.message)
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, user: user, account: Current.account).capture_exception
    log(tool_name, tool_arguments, 'error', e.message, started_at)
    tool_error("Não foi possível executar #{tool_name}: #{e.message}")
  end

  def tool_result(data)
    { 'content' => [{ 'type' => 'text', 'text' => JSON.pretty_generate(data) }] }
  end

  def tool_error(message)
    { 'content' => [{ 'type' => 'text', 'text' => message }], 'isError' => true }
  end

  def success(result)
    { 'jsonrpc' => '2.0', 'id' => id, 'result' => result }
  end

  def error_response(request_id, code, message)
    { 'jsonrpc' => '2.0', 'id' => request_id, 'error' => { 'code' => code, 'message' => message } }
  end

  def log(tool_name, tool_arguments, status, error_message, started_at)
    McpRequestLog.create!(
      account_id: Current.account&.id,
      user_id: user.id,
      tool_name: tool_name,
      arguments: tool_arguments,
      status: status,
      error_message: error_message,
      duration_ms: ((Time.current - started_at) * 1000).round
    )
  rescue StandardError => e
    Rails.logger.error("[MCP] falha ao registrar log da ferramenta #{tool_name}: #{e.message}")
  end
end
