class Mcp::Tools::EnviarMensagem < Mcp::Tools::Base
  class << self
    def tool_name
      'enviar_mensagem'
    end

    def description
      'Envia uma resposta em uma conversa do Connect pelo fluxo normal do produto: ' \
        'a mensagem sai pelo canal do cliente e fica registrada no histórico. Confirme o texto com o usuário antes de enviar.'
    end

    def input_schema
      {
        'type' => 'object',
        'properties' => {
          'conversation_id' => { 'type' => 'integer', 'description' => 'ID da conversa que receberá a resposta.' },
          'mensagem' => { 'type' => 'string', 'description' => 'Texto da mensagem a enviar.' },
          'nota_interna' => {
            'type' => 'boolean',
            'description' => 'Quando true, registra uma nota privada visível apenas para a equipe. Padrão: false.'
          }
        }.merge(account_id_property),
        'required' => %w[conversation_id mensagem]
      }
    end
  end

  def perform
    raise Mcp::Error, 'Informe o texto da mensagem.' if arguments[:mensagem].blank?

    conversation = find_conversation!(arguments[:conversation_id])
    message = Messages::MessageBuilder.new(user, conversation, message_params).perform

    {
      enviada: true,
      conversation_id: conversation.display_id,
      canal: conversation.inbox&.name,
      contato: present_contact(conversation.contact),
      mensagem: present_message(message)
    }.compact
  end

  private

  def message_params
    ActionController::Parameters.new(
      content: arguments[:mensagem].to_s,
      message_type: 'outgoing',
      private: ActiveModel::Type::Boolean.new.cast(arguments[:nota_interna]) || false
    )
  end
end
