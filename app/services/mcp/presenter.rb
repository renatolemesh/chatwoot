# Serializadores compartilhados pelas ferramentas MCP. As chaves são em português
# para que o modelo do ChatGPT interprete os campos sem instruções extras.
module Mcp::Presenter
  private

  def present_contact(contact)
    return nil if contact.blank?

    {
      id: contact.id,
      nome: contact.name,
      email: contact.email,
      telefone: contact.phone_number,
      identificador: contact.identifier
    }.compact
  end

  def present_conversation(conversation, last_message: nil)
    {
      conversation_id: conversation.display_id,
      canal: conversation.inbox&.name,
      tipo_de_canal: conversation.inbox&.channel_type,
      status: conversation.status,
      prioridade: conversation.priority,
      responsavel: conversation.assignee&.available_name,
      time: conversation.team&.name,
      contato: present_contact(conversation.contact),
      ultima_mensagem: last_message&.content,
      ultima_mensagem_de: last_message&.message_type,
      ultima_atividade_em: present_time(conversation.last_activity_at),
      criada_em: present_time(conversation.created_at),
      nao_lida: unread?(conversation, last_message),
      etiquetas: conversation.cached_label_list_array.presence
    }.compact
  end

  def present_message(message)
    {
      id: message.id,
      data: present_time(message.created_at),
      tipo: message.message_type,
      remetente: message.sender.try(:available_name) || message.sender&.name,
      remetente_tipo: message.sender_type,
      privada: message.private,
      conteudo: message.content,
      anexos: message.attachments.map { |attachment| { tipo: attachment.file_type, url: attachment.download_url } }.presence
    }.compact
  end

  # Mesma definição de "não lida" usada pelo filtro de conversas: conversa aberta,
  # última mensagem vinda do cliente e ainda não vista pelo agente.
  def unread?(conversation, last_message)
    return nil if last_message.blank?

    conversation.open? && last_message.incoming? &&
      (conversation.agent_last_seen_at.blank? || conversation.agent_last_seen_at < conversation.last_activity_at)
  end

  # Uma única consulta traz a última mensagem de cada conversa da página,
  # evitando um SELECT por conversa na montagem da lista.
  def last_messages_by_conversation(conversation_ids)
    return {} if conversation_ids.blank?

    Message.where(conversation_id: conversation_ids)
           .where(message_type: [:incoming, :outgoing])
           .select('DISTINCT ON (messages.conversation_id) messages.*')
           .reorder('messages.conversation_id, messages.created_at DESC')
           .index_by(&:conversation_id)
  end

  def present_time(time)
    time&.iso8601
  end

  def parse_time(value)
    return nil if value.blank?

    Time.zone.parse(value.to_s) || invalid_date!(value)
  rescue ArgumentError
    invalid_date!(value)
  end

  def invalid_date!(value)
    raise Mcp::Error, "Data inválida: #{value}. Use o formato ISO 8601, por exemplo 2026-08-29 ou 2026-08-29T09:00:00."
  end
end
