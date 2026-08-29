class Mcp::Tools::ListarConversas < Mcp::Tools::Base
  ASSIGNEE_TYPES = { 'minhas' => 'me', 'nao_atribuidas' => 'unassigned', 'atribuidas' => 'assigned', 'todas' => 'all' }.freeze

  class << self
    def tool_name
      'listar_conversas'
    end

    def description
      'Lista as conversas do Connect, com filtros por canal (inbox), status, período, ' \
        'responsável e apenas não lidas. Use para responder perguntas como "quais as mensagens novas do Comercial?".'
    end

    def input_schema
      {
        'type' => 'object',
        'properties' => filter_properties.merge(period_properties).merge(account_id_property),
        'required' => []
      }
    end

    def filter_properties
      {
        'canal' => { 'type' => 'string', 'description' => 'Nome ou ID do canal/caixa de entrada. Ex.: "Comercial".' },
        'status' => {
          'type' => 'string',
          'enum' => %w[open pending resolved snoozed all],
          'description' => 'Status das conversas. Padrão: open (em aberto).'
        },
        'apenas_nao_lidas' => { 'type' => 'boolean', 'description' => 'Somente conversas em aberto com mensagens do cliente ainda não lidas.' },
        'responsavel' => {
          'type' => 'string',
          'enum' => %w[todas minhas nao_atribuidas atribuidas],
          'description' => 'Filtra pelo responsável da conversa. Padrão: todas.'
        },
        'busca' => { 'type' => 'string', 'description' => 'Texto a procurar no conteúdo das mensagens.' }
      }
    end

    def period_properties
      {
        'desde' => { 'type' => 'string', 'description' => 'Data/hora inicial da última atividade, em ISO 8601.' },
        'ate' => { 'type' => 'string', 'description' => 'Data/hora final da última atividade, em ISO 8601.' },
        'pagina' => { 'type' => 'integer', 'description' => 'Página de resultados (25 por página). Padrão: 1.' }
      }
    end
  end

  def perform
    result = ConversationFinder.new(user, finder_params).perform
    conversations = filter_by_period(result[:conversations]).to_a
    last_messages = last_messages_by_conversation(conversations.map(&:id))

    {
      canal: inbox&.name,
      status: status,
      pagina: page,
      retornadas: conversations.size,
      total_no_canal_e_status: result.dig(:count, :all_count),
      conversas: conversations.map { |conversation| present_conversation(conversation, last_message: last_messages[conversation.id]) }
    }.compact
  end

  private

  def inbox
    @inbox ||= find_inbox!(arguments[:canal])
  end

  def status
    return 'unread' if ActiveModel::Type::Boolean.new.cast(arguments[:apenas_nao_lidas])

    arguments[:status].presence || 'open'
  end

  def page
    [arguments[:pagina].to_i, 1].max
  end

  def finder_params
    {
      inbox_id: inbox&.id,
      status: status,
      assignee_type: ASSIGNEE_TYPES[arguments[:responsavel].to_s],
      q: arguments[:busca].presence,
      page: page,
      sort_by: 'last_activity_at_desc'
    }.compact.with_indifferent_access
  end

  # O ConversationFinder não filtra por período; encadeamos o intervalo na relação
  # devolvida por ele, preservando as regras de permissão já aplicadas.
  def filter_by_period(conversations)
    since = parse_time(arguments[:desde])
    until_time = parse_time(arguments[:ate])

    conversations = conversations.where(conversations: { last_activity_at: since.. }) if since
    conversations = conversations.where(conversations: { last_activity_at: ..until_time }) if until_time
    conversations
  end
end
