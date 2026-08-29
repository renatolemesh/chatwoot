class Mcp::Tools::EnviarMensagem < Mcp::Tools::Base
  class << self
    def tool_name
      'enviar_mensagem'
    end

    def description
      'Envia uma resposta em uma conversa do Connect pelo fluxo normal do produto: ' \
        'a mensagem sai pelo canal do cliente e fica registrada no histórico. Confirme o texto com o usuário antes de enviar. ' \
        'Só funciona dentro da janela de atendimento do canal (ver pode_responder em ler_conversa); fora dela o canal exige modelo aprovado.'
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
    ensure_within_reply_window!(conversation) unless private_note?
    message = Messages::MessageBuilder.new(user, conversation, message_params).perform

    {
      registrada_no_connect: true,
      status_de_entrega: message.status,
      observacao: 'A entrega pelo canal é assíncrona. Confirme o status final com ler_conversa.',
      conversation_id: conversation.display_id,
      canal: conversation.inbox&.name,
      contato: present_contact(conversation.contact),
      mensagem: present_message(message)
    }.compact
  end

  private

  # Canais como o WhatsApp oficial só aceitam texto livre dentro da janela de
  # atendimento; fora dela exigem um modelo aprovado, que esta ferramenta não
  # envia. Sem esta checagem a mensagem seria criada e falharia na entrega.
  def ensure_within_reply_window!(conversation)
    return if conversation.can_reply?

    raise Mcp::Error,
          "A janela de atendimento do canal '#{conversation.inbox&.name}' está fechada: faz tempo demais que o contato não escreve. " \
          'Nesse estado o canal só aceita modelo (template) aprovado, que esta ferramenta não envia. ' \
          'Mande o template pela interface do Connect, ou registre uma nota interna com nota_interna: true.'
  end

  def private_note?
    ActiveModel::Type::Boolean.new.cast(arguments[:nota_interna]) || false
  end

  def message_params
    ActionController::Parameters.new(
      content: arguments[:mensagem].to_s,
      message_type: 'outgoing',
      private: private_note?
    )
  end
end
