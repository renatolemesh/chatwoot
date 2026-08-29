class Mcp::Tools::RelatorioPor < Mcp::Tools::Base
  include Mcp::Reports

  BUILDERS = {
    'agente' => V2::Reports::AgentSummaryBuilder,
    'canal' => V2::Reports::InboxSummaryBuilder,
    'equipe' => V2::Reports::TeamSummaryBuilder,
    'etiqueta' => V2::Reports::LabelSummaryBuilder
  }.freeze

  DEFAULT_LIMIT = 20

  class << self
    def tool_name
      'relatorio_por'
    end

    def description
      'Compara o desempenho por agente, canal, equipe ou etiqueta em um período: uma linha para cada, ' \
        'com conversas, resoluções e tempos médios. Responde "quem atendeu mais?" e ' \
        '"qual canal demora mais para responder?". Exige permissão de relatórios.'
    end

    def input_schema
      {
        'type' => 'object',
        'properties' => {
          'dimensao' => {
            'type' => 'string',
            'enum' => BUILDERS.keys,
            'description' => 'O que comparar: agente, canal, equipe ou etiqueta.'
          },
          'limite' => { 'type' => 'integer', 'description' => "Quantas linhas devolver. Padrão: #{DEFAULT_LIMIT}." }
        }.merge(period_properties).merge(account_id_property),
        'required' => ['dimensao']
      }
    end
  end

  def perform
    authorize_reports!
    rows = builder.new(account: account, params: builder_params).build

    {
      periodo: present_period,
      dimensao: dimension,
      linhas: sorted(rows).map { |row| present_row(row) }
    }
  end

  private

  def dimension
    @dimension ||= arguments[:dimensao].to_s.downcase
  end

  def builder
    BUILDERS[dimension] || raise(Mcp::Error, "Dimensão inválida. Use uma destas: #{BUILDERS.keys.join(', ')}.")
  end

  def sorted(rows)
    rows.sort_by { |row| -row[:conversations_count].to_i }.first(limit)
  end

  def limit
    requested = arguments[:limite].to_i
    requested.positive? ? requested : DEFAULT_LIMIT
  end

  def present_row(row)
    { nome: row_name(row) }.merge(present_metrics(row)).compact
  end

  def row_name(row)
    return row[:name] if row[:name].present?

    names.fetch(row[:id], "##{row[:id]}")
  end

  def names
    @names ||= case dimension
               when 'agente' then account.users.pluck(:id, :name).to_h
               when 'canal' then account.inboxes.pluck(:id, :name).to_h
               when 'equipe' then account.teams.pluck(:id, :name).to_h
               else {}
               end
  end
end
