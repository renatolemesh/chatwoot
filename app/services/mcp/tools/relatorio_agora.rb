class Mcp::Tools::RelatorioAgora < Mcp::Tools::Base
  include Mcp::Reports

  class << self
    def tool_name
      'relatorio_agora'
    end

    def description
      'Fotografia do momento, sem período: quantas conversas estão abertas, não atendidas, sem responsável e pendentes, ' \
        'no total e por canal. Responde "como estamos agora?". Exige permissão de relatórios.'
    end

    def input_schema
      {
        'type' => 'object',
        'properties' => {
          'por_canal' => { 'type' => 'boolean', 'description' => 'Inclui a abertura por caixa de entrada. Padrão: true.' }
        }.merge(account_id_property),
        'required' => []
      }
    end
  end

  def perform
    authorize_reports!
    result = { momento: present_time(Time.current), total: totals }
    result[:por_canal] = per_inbox if per_inbox?
    result
  end

  private

  def conversations
    @conversations ||= account.conversations
  end

  def totals
    {
      abertas: conversations.open.count,
      nao_atendidas: conversations.open.unattended.count,
      sem_responsavel: conversations.open.unassigned.count,
      pendentes: conversations.pending.count
    }
  end

  def per_inbox?
    arguments[:por_canal].nil? || ActiveModel::Type::Boolean.new.cast(arguments[:por_canal])
  end

  def per_inbox
    counts = {
      abertas: conversations.open.group(:inbox_id).count,
      nao_atendidas: conversations.open.unattended.group(:inbox_id).count,
      sem_responsavel: conversations.open.unassigned.group(:inbox_id).count
    }
    rows = account.inboxes.map { |inbox| inbox_row(inbox, counts) }
    rows.sort_by { |row| -row[:abertas] }
  end

  def inbox_row(inbox, counts)
    { canal: inbox.name }.merge(counts.transform_values { |by_inbox| by_inbox[inbox.id] || 0 })
  end
end
