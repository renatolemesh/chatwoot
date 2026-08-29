# Base das ferramentas de relatório: permissão, recorte de período e formatação
# de durações. Os cálculos ficam nos builders V2::Reports::*, os mesmos que
# alimentam a tela de Relatórios do Connect.
module Mcp::Reports
  extend ActiveSupport::Concern

  DEFAULT_PERIOD_DAYS = 7

  class_methods do
    def period_properties
      {
        'desde' => { 'type' => 'string', 'description' => "Início do período, em ISO 8601. Padrão: #{DEFAULT_PERIOD_DAYS} dias atrás." },
        'ate' => { 'type' => 'string', 'description' => 'Fim do período, em ISO 8601. Padrão: agora.' },
        'horario_comercial' => {
          'type' => 'boolean',
          'description' => 'Quando true, os tempos médios contam apenas o horário comercial da conta. Padrão: false.'
        }
      }
    end
  end

  private

  # Quem pode ver relatório é o administrador ou, no Enterprise, quem tem um
  # papel com report_manage. Reusa a ReportPolicy em vez de repetir a regra.
  def authorize_reports!
    context = { user: user, account: account, account_user: Current.account_user }
    return if ReportPolicy.new(context, :report).view?

    raise Mcp::Error, 'Este token não tem permissão de relatórios. É preciso ser administrador ou ter um papel com a permissão de relatórios.'
  end

  def period
    @period ||= build_period
  end

  def build_period
    until_time = parse_time(arguments[:ate]) || Time.current
    since_time = parse_time(arguments[:desde]) || (until_time - DEFAULT_PERIOD_DAYS.days)
    raise Mcp::Error, 'A data inicial precisa ser anterior à final.' if since_time > until_time

    { since: since_time, until: until_time }
  end

  def builder_params
    { since: period[:since].to_i.to_s, until: period[:until].to_i.to_s, business_hours: business_hours? }
  end

  def business_hours?
    ActiveModel::Type::Boolean.new.cast(arguments[:horario_comercial]) || false
  end

  def present_period
    { desde: present_time(period[:since]), ate: present_time(period[:until]), horario_comercial: business_hours? }
  end

  def present_duration(seconds)
    total = seconds.to_f.round
    return nil if total <= 0
    return "#{total}s" if total < 60
    return "#{total / 60}min #{total % 60}s" if total < 3600
    return "#{total / 3600}h #{total % 3600 / 60}min" if total < 86_400

    "#{total / 86_400}d #{total % 86_400 / 3600}h"
  end

  def present_metrics(row)
    {
      conversas: row[:conversations_count].to_i,
      resolvidas: row[:resolved_conversations_count].to_i,
      tempo_medio_primeira_resposta: present_duration(row[:avg_first_response_time]),
      tempo_medio_resolucao: present_duration(row[:avg_resolution_time]),
      tempo_medio_de_resposta: present_duration(row[:avg_reply_time])
    }.compact
  end
end
