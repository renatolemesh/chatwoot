class Mcp::Tools::AtribuirConversa < Mcp::Tools::Base
  # Termos que o assistente costuma usar para dizer "tire o responsável".
  REMOVAL_TERMS = ['ninguem', 'ninguém', 'nenhum', 'nenhuma', 'remover', 'sem responsavel', 'sem responsável'].freeze

  class << self
    def tool_name
      'atribuir_conversa'
    end

    def description
      'Troca o responsável e/ou o time de uma conversa do Connect, como se a mudança fosse feita na tela: ' \
        'a conversa passa para a fila de quem recebeu e o histórico registra quem atribuiu. ' \
        'Informe agente, time, ou os dois. Confirme com o usuário antes de atribuir.'
    end

    def input_schema
      {
        'type' => 'object',
        'properties' => {
          'conversation_id' => { 'type' => 'integer', 'description' => 'ID da conversa.' },
          'agente' => {
            'type' => 'string',
            'description' => 'Nome, e-mail ou ID do agente que vai atender. Use "ninguem" para deixar sem responsável.'
          },
          'time' => {
            'type' => 'string',
            'description' => 'Nome ou ID do time. Use "nenhum" para tirar o time.'
          }
        }.merge(account_id_property),
        'required' => ['conversation_id']
      }
    end
  end

  def perform
    conversation = find_conversation!(arguments[:conversation_id])
    raise Mcp::Error, 'Informe o agente, o time, ou os dois.' if arguments[:agente].blank? && arguments[:time].blank?

    # O time vem primeiro: trocar o time limpa o responsável que não pertence a ele
    # (AssignmentHandler#ensure_assignee_is_from_team). Definindo o agente depois,
    # a conversa fica com quem o usuário pediu, e não sem responsável.
    assign_team(conversation) if arguments[:time].present?
    assign_agent(conversation) if arguments[:agente].present?

    { atribuida: true, conversa: present_conversation(conversation.reload) }
  end

  private

  def assign_agent(conversation)
    Conversations::AssignmentService.new(conversation: conversation, assignee_id: agent_for(conversation.inbox)&.id).perform
  end

  def assign_team(conversation)
    conversation.update!(team: team_for)
  end

  # O agente precisa atender o canal da conversa: atribuir para fora disso deixaria
  # a conversa numa fila que a pessoa não enxerga.
  def agent_for(inbox)
    term = arguments[:agente].to_s.strip
    return nil if removal?(term)

    candidates = inbox.assignable_agents
    agent = candidates.find { |user| user.id.to_s == term || user.email.to_s.casecmp?(term) } ||
            match_by_name(candidates, term, 'Agente')
    raise Mcp::Error, "Agente '#{term}' não atende o canal '#{inbox.name}'. Quem atende: #{names_of(candidates)}." if agent.blank?

    agent
  end

  def team_for
    term = arguments[:time].to_s.strip
    return nil if removal?(term)

    teams = account.teams.to_a
    team = teams.find { |record| record.id.to_s == term } || match_by_name(teams, term, 'Time')
    raise Mcp::Error, "Time '#{term}' não existe nesta conta. Times: #{names_of(teams)}." if team.blank?

    team
  end

  def removal?(term)
    REMOVAL_TERMS.include?(term.downcase)
  end

  def names_of(records)
    records.map { |record| display_name(record) }.join(', ')
  end
end
