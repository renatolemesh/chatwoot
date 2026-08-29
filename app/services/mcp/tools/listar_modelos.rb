class Mcp::Tools::ListarModelos < Mcp::Tools::Base
  include Mcp::Templates

  class << self
    def tool_name
      'listar_modelos'
    end

    def description
      'Lista os modelos (templates) aprovados de um canal do WhatsApp oficial, com o texto e as variáveis de cada um. ' \
        'Use quando pode_responder for false: fora da janela de atendimento só um modelo pode ser enviado.'
    end

    def input_schema
      {
        'type' => 'object',
        'properties' => {
          'canal' => { 'type' => 'string', 'description' => 'Nome ou ID do canal. Ex.: "Comercial Oficial".' },
          'busca' => { 'type' => 'string', 'description' => 'Filtra por parte do nome ou do texto do modelo.' }
        }.merge(account_id_property),
        'required' => ['canal']
      }
    end
  end

  def perform
    inbox = find_inbox!(arguments[:canal])

    { canal: inbox.name, modelos: matching_templates(inbox).map { |template| present_template(template) } }
  end

  private

  def matching_templates(inbox)
    templates = approved_templates(inbox)
    term = arguments[:busca].to_s.strip
    return templates if term.blank?

    templates.select { |template| "#{template['name']} #{template_body(template)}".match?(/#{Regexp.escape(term)}/i) }
  end

  def present_template(template)
    reason = unsupported_template_reason(template)

    {
      nome: template['name'],
      idioma: template['language'],
      categoria: template['category'],
      formato_das_variaveis: named_parameters?(template) ? 'nomeado' : 'posicional',
      variaveis: template_variables(template).presence,
      texto: template_body(template),
      botoes: button_labels(template).presence,
      disponivel: reason.nil?,
      indisponivel_porque: reason
    }.compact
  end

  def button_labels(template)
    buttons = component(template, 'BUTTONS')&.fetch('buttons', nil) || []
    buttons.filter_map { |button| button['text'] }
  end
end
