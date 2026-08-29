class Mcp::Tools::BuscarContato < Mcp::Tools::Base
  DEFAULT_LIMIT = 10
  MAX_LIMIT = 50

  class << self
    def tool_name
      'buscar_contato'
    end

    def description
      'Busca contatos do Connect por nome, telefone, e-mail, identificador ou ID, ' \
        'devolvendo também as conversas recentes de cada contato.'
    end

    def input_schema
      {
        'type' => 'object',
        'properties' => {
          'termo' => { 'type' => 'string', 'description' => 'Nome, telefone, e-mail ou identificador do contato.' },
          'contato_id' => { 'type' => 'integer', 'description' => 'ID exato do contato, quando já conhecido.' },
          'limite' => { 'type' => 'integer', 'description' => "Quantidade máxima de contatos. Padrão: #{DEFAULT_LIMIT}." }
        }.merge(account_id_property),
        'required' => []
      }
    end
  end

  def perform
    { contatos: contacts.map { |contact| present_contact(contact).merge(conversas: conversations_for(contact)) } }
  end

  private

  def contacts
    return account.contacts.where(id: arguments[:contato_id]) if arguments[:contato_id].present?

    raise Mcp::Error, 'Informe o termo de busca ou o contato_id.' if arguments[:termo].blank?

    account.contacts
           .where(
             'name ILIKE :term OR email ILIKE :term OR phone_number ILIKE :term OR contacts.identifier ILIKE :term',
             term: "%#{arguments[:termo].to_s.strip}%"
           )
           .order(Arel.sql('last_activity_at DESC NULLS LAST'))
           .limit(limit)
  end

  def conversations_for(contact)
    accessible_conversations
      .where(contact_id: contact.id)
      .includes(:inbox, :assignee)
      .order(last_activity_at: :desc)
      .limit(5)
      .map do |conversation|
        {
          conversation_id: conversation.display_id,
          canal: conversation.inbox&.name,
          status: conversation.status,
          responsavel: conversation.assignee&.name,
          ultima_atividade_em: present_time(conversation.last_activity_at)
        }.compact
      end
  end

  def limit
    requested = arguments[:limite].to_i
    return DEFAULT_LIMIT if requested <= 0

    [requested, MAX_LIMIT].min
  end
end
