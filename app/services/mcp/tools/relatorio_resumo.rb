class Mcp::Tools::RelatorioResumo < Mcp::Tools::Base
  include Mcp::Reports

  FILTERS = %w[canal agente equipe etiqueta].freeze

  class << self
    def tool_name
      'relatorio_resumo'
    end

    def description
      'Números de atendimento de um período: conversas, resoluções, mensagens recebidas e enviadas, ' \
        'tempo médio de primeira resposta e de resolução. Pode recortar por canal, agente, equipe ou etiqueta. ' \
        'Responde perguntas como "como foi o Comercial esta semana?". Exige permissão de relatórios.'
    end

    def input_schema
      {
        'type' => 'object',
        'properties' => {
          'canal' => { 'type' => 'string', 'description' => 'Nome ou ID do canal, para olhar só uma caixa de entrada.' },
          'agente' => { 'type' => 'string', 'description' => 'Nome, e-mail ou ID do agente.' },
          'equipe' => { 'type' => 'string', 'description' => 'Nome ou ID da equipe.' },
          'etiqueta' => { 'type' => 'string', 'description' => 'Nome da etiqueta.' }
        }.merge(period_properties).merge(account_id_property),
        'required' => []
      }
    end
  end

  def perform
    authorize_reports!
    summary = V2::Reports::Conversations::MetricBuilder.new(account, builder_params.merge(scope)).summary

    {
      periodo: present_period,
      recorte: scope_label,
      conversas: summary[:conversations_count].to_i,
      resolvidas: summary[:resolutions_count].to_i,
      mensagens_recebidas: summary[:incoming_messages_count].to_i,
      mensagens_enviadas: summary[:outgoing_messages_count].to_i,
      tempo_medio_primeira_resposta: present_duration(summary[:avg_first_response_time]),
      tempo_medio_resolucao: present_duration(summary[:avg_resolution_time]),
      tempo_medio_de_resposta: present_duration(summary[:reply_time])
    }.compact
  end

  private

  def scope
    @scope ||= build_scope
  end

  def build_scope
    given = FILTERS.select { |name| arguments[name].present? }
    raise Mcp::Error, "Use um recorte por vez. Recebi: #{given.join(', ')}." if given.size > 1

    case given.first
    when 'canal' then inbox_scope
    when 'agente' then agent_scope
    when 'equipe' then team_scope
    when 'etiqueta' then label_scope
    else { type: :account }
    end
  end

  def inbox_scope
    inbox = find_inbox!(arguments[:canal])
    @scope_label = "canal: #{inbox.name}"
    { type: :inbox, id: inbox.id }
  end

  def agent_scope
    term = arguments[:agente].to_s.strip
    agent = account.users.find_by(id: term) if term.match?(/\A\d+\z/)
    agent ||= account.users.find_by('name ILIKE :term OR email ILIKE :term', term: "%#{term}%")
    raise Mcp::Error, "Agente '#{term}' não encontrado nesta conta." if agent.blank?

    @scope_label = "agente: #{agent.available_name}"
    { type: :agent, id: agent.id }
  end

  def team_scope
    term = arguments[:equipe].to_s.strip
    team = account.teams.find_by(id: term) if term.match?(/\A\d+\z/)
    team ||= account.teams.find_by('name ILIKE ?', "%#{term}%")
    raise Mcp::Error, "Equipe '#{term}' não encontrada. Disponíveis: #{account.teams.pluck(:name).join(', ')}." if team.blank?

    @scope_label = "equipe: #{team.name}"
    { type: :team, id: team.id }
  end

  def label_scope
    term = arguments[:etiqueta].to_s.strip
    label = account.labels.find_by('title ILIKE ?', term)
    raise Mcp::Error, "Etiqueta '#{term}' não encontrada." if label.blank?

    @scope_label = "etiqueta: #{label.title}"
    { type: :label, id: label.id }
  end

  def scope_label
    scope
    @scope_label || 'conta inteira'
  end
end
