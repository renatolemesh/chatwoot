class Mcp::Tools::RelatorioGargalos < Mcp::Tools::Base
  include Mcp::Reports

  MAX_REASONS = 8

  class << self
    def tool_name
      'relatorio_gargalos'
    end

    def description
      'Onde o atendimento trava num período: percentis de espera (a cauda que a média esconde), conversas que nunca ' \
        'receberam resposta, encerramentos sem resposta, quantas conversas seguiam abertas no fim do período e os ' \
        'motivos de encerramento registrados. Responde perguntas como "quem esperou mais?" e "o que está caindo no ' \
        'vão?". Exige permissão de relatórios.'
    end

    def input_schema
      {
        'type' => 'object',
        'properties' => period_properties.merge(account_id_property),
        'required' => []
      }
    end
  end

  def perform
    authorize_reports!

    {
      periodo: present_period,
      espera_ate_a_primeira_resposta: present_percentiles(percentiles[:first_response_time]),
      tempo_ate_resolver: present_percentiles(percentiles[:resolution_time]),
      recebidas: funnel[:received],
      nunca_respondidas: funnel[:unanswered],
      encerradas_sem_resposta: funnel[:resolved_without_answer],
      avaliadas_csat: funnel[:rated],
      abertas_no_fim_do_periodo: backlog.last&.fetch(:value, nil),
      motivos_de_encerramento: present_reasons
    }.compact
  end

  private

  def percentiles
    @percentiles ||= V2::Reports::ResponseTimePercentilesBuilder.new(account: account, params: builder_params).build
  end

  def funnel
    @funnel ||= V2::Reports::ConversationFunnelBuilder.new(account: account, params: builder_params).build
  end

  def reasons
    @reasons ||= V2::Reports::ResolutionReasonsBuilder.new(account: account, params: builder_params).build
  end

  def backlog
    @backlog ||= V2::Reports::ConversationBacklogBuilder.new(account: account, params: builder_params).build
  end

  # present_duration devolve nil para zero, mas aqui zero é informação: quer dizer
  # que metade das conversas foi respondida na hora.
  def present_percentiles(row)
    return nil if row.blank? || row[:count].to_i.zero?

    {
      metade_espera_ate: present_wait(row[:p50]),
      '90%_espera_ate': present_wait(row[:p90]),
      '95%_espera_ate': present_wait(row[:p95]),
      amostra: row[:count].to_i
    }
  end

  def present_wait(seconds)
    return nil if seconds.nil?

    present_duration(seconds) || '0s'
  end

  # A cobertura vem junto de propósito: um ranking sobre 15% dos encerramentos
  # não deve ser lido como o retrato dos motivos.
  def present_reasons
    return nil if reasons[:total].to_i.zero?

    {
      encerramentos: reasons[:total],
      com_etiqueta: reasons[:labelled],
      sem_etiqueta: reasons[:unlabelled],
      etiquetas: reasons[:labels].first(MAX_REASONS).map { |label| { etiqueta: label[:name], encerramentos: label[:count] } }
    }
  end
end
