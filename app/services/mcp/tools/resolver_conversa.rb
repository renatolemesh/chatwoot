class Mcp::Tools::ResolverConversa < Mcp::Tools::Base
  STATUSES = { 'resolvida' => 'resolved', 'aberta' => 'open', 'pendente' => 'pending' }.freeze

  class << self
    def tool_name
      'resolver_conversa'
    end

    def description
      'Conclui uma conversa do Connect, marcando como resolvida. Também reabre ou marca como pendente, pelo parâmetro status. ' \
        'A mudança segue o fluxo normal do produto: dispara a pesquisa de satisfação e as automações do canal, ' \
        'e o histórico registra quem alterou. Confirme com o usuário antes.'
    end

    def input_schema
      {
        'type' => 'object',
        'properties' => {
          'conversation_id' => { 'type' => 'integer', 'description' => 'ID da conversa.' },
          'status' => {
            'type' => 'string',
            'enum' => STATUSES.keys,
            'description' => 'Situação desejada. Padrão: resolvida.'
          }
        }.merge(account_id_property),
        'required' => ['conversation_id']
      }
    end
  end

  def perform
    conversation = find_conversation!(arguments[:conversation_id])
    previous = conversation.status
    conversation.update!(status: target_status)

    { atualizada: true, status_anterior: previous, conversa: present_conversation(conversation.reload) }
  end

  private

  def target_status
    term = arguments[:status].to_s.strip.downcase.presence || 'resolvida'
    STATUSES.fetch(term) { raise Mcp::Error, "Status '#{term}' não existe. Use: #{STATUSES.keys.join(', ')}." }
  end
end
