# Base das ferramentas MCP. Resolve a conta do token, prepara o `Current` usado
# pelos finders/serviços do Connect e concentra as checagens de permissão.
class Mcp::Tools::Base
  include Mcp::Presenter

  attr_reader :user, :arguments, :account

  def initialize(user:, arguments: {})
    @user = user
    @arguments = (arguments || {}).with_indifferent_access
    @account = resolve_account!
  end

  def perform
    raise NotImplementedError
  end

  class << self
    def schema
      { 'name' => tool_name, 'description' => description, 'inputSchema' => input_schema }
    end

    def account_id_property
      {
        'account_id' => {
          'type' => 'integer',
          'description' => 'ID da conta do Connect. Opcional: por padrão usa a conta do token.'
        }
      }
    end
  end

  private

  def resolve_account!
    account_user = find_account_user
    raise Mcp::Error, 'Nenhuma conta do Connect acessível para este token.' if account_user.blank?
    raise Mcp::Error, 'A conta está suspensa.' unless account_user.account.active?

    Current.user = user
    Current.account = account_user.account
    Current.account_user = account_user
    account_user.account
  end

  def find_account_user
    return user.account_users.find_by(account_id: arguments[:account_id]) if arguments[:account_id].present?

    user.account_users.order(:account_id).first
  end

  # Mesma regra de visibilidade da caixa de entrada usada pela API/UI:
  # o agente só enxerga as inboxes atribuídas a ele; o administrador vê todas.
  def accessible_conversations
    scope = account.conversations.where(inbox_id: user.assigned_inboxes.select(:id))
    Conversations::PermissionFilterService.new(scope, user, account).perform
  end

  def find_conversation!(identifier)
    raise Mcp::Error, 'Informe o conversation_id da conversa.' if identifier.blank?

    conversation = accessible_conversations.find_by(display_id: identifier) ||
                   accessible_conversations.find_by(id: identifier)
    raise Mcp::Error, "Conversa #{identifier} não encontrada ou fora dos canais liberados para este usuário." if conversation.blank?

    conversation
  end

  def find_inbox!(term)
    return nil if term.blank?

    scope = user.assigned_inboxes
    inbox = term.to_s.match?(/\A\d+\z/) ? scope.find_by(id: term) : match_inbox_by_name(scope, term)
    raise Mcp::Error, "Canal '#{term}' não encontrado. Canais disponíveis: #{scope.pluck(:name).join(', ')}." if inbox.blank?

    inbox
  end

  def match_inbox_by_name(scope, term)
    name = term.to_s.strip
    scope.find_by('name ILIKE ?', name) || scope.find_by('name ILIKE ?', "%#{name}%")
  end
end
