class Mcp::Tools::LerConversa < Mcp::Tools::Base
  DEFAULT_LIMIT = 50
  MAX_LIMIT = 200

  class << self
    def tool_name
      'ler_conversa'
    end

    def description
      'Lê uma conversa do Connect: dados do contato, canal, status, responsável e o histórico de mensagens em ordem cronológica. ' \
        'Traz também pode_responder, que indica se o canal aceita uma resposta de texto agora.'
    end

    def input_schema
      {
        'type' => 'object',
        'properties' => {
          'conversation_id' => { 'type' => 'integer', 'description' => 'ID da conversa, como devolvido por listar_conversas.' },
          'limite' => { 'type' => 'integer', 'description' => "Quantidade de mensagens mais recentes a retornar. Padrão: #{DEFAULT_LIMIT}." },
          'incluir_notas_internas' => { 'type' => 'boolean', 'description' => 'Inclui notas privadas e mensagens de atividade. Padrão: true.' }
        }.merge(account_id_property),
        'required' => ['conversation_id']
      }
    end
  end

  def perform
    conversation = find_conversation!(arguments[:conversation_id])
    messages = messages_for(conversation)
    last_message = messages.reverse.find { |message| message.incoming? || message.outgoing? }

    present_conversation(conversation, last_message: last_message).merge(
      pode_responder: conversation.can_reply?,
      mensagens: messages.map { |message| present_message(message) }
    )
  end

  private

  def messages_for(conversation)
    scope = conversation.messages.includes(:attachments, :sender)
    scope = scope.where(private: false).where.not(message_type: :activity) unless include_internal?
    scope.reorder(created_at: :desc).limit(limit).reverse
  end

  def include_internal?
    return true if arguments[:incluir_notas_internas].nil?

    ActiveModel::Type::Boolean.new.cast(arguments[:incluir_notas_internas])
  end

  def limit
    requested = arguments[:limite].to_i
    return DEFAULT_LIMIT if requested <= 0

    [requested, MAX_LIMIT].min
  end
end
