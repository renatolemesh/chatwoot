# Leitura dos modelos (templates) aprovados de um canal do WhatsApp oficial.
# Compartilhado por listar_modelos e enviar_mensagem.
module Mcp::Templates
  private

  def approved_templates(inbox)
    channel = inbox.channel
    unless channel.respond_to?(:message_templates)
      raise Mcp::Error, "O canal '#{inbox.name}' não trabalha com modelos aprovados; use uma mensagem de texto comum."
    end

    (channel.message_templates || []).select { |template| template['status'].to_s.casecmp('approved').zero? }
  end

  def template_body(template)
    component(template, 'BODY')&.fetch('text', nil).to_s
  end

  def template_variables(template)
    template_body(template).scan(/\{\{(.*?)\}\}/).flatten.map(&:strip)
  end

  def named_parameters?(template)
    template['parameter_format'].to_s.casecmp('named').zero?
  end

  def component(template, type)
    (template['components'] || []).find { |item| item['type'].to_s.casecmp(type).zero? }
  end

  # Cabeçalho com mídia, variável no cabeçalho e botão que exige parâmetro
  # precisam de dados que esta ferramenta não coleta. Melhor recusar com o
  # motivo do que montar um envio que a Meta rejeita.
  def unsupported_template_reason(template)
    return 'exige mídia no cabeçalho' if media_header?(template)
    return 'tem variável no cabeçalho' if variable_text_header?(template)
    return 'tem botão que exige parâmetro' if parameterized_button?(template)

    nil
  end

  def media_header?(template)
    header = component(template, 'HEADER')
    header.present? && header['format'].to_s.casecmp('text').nonzero?
  end

  def variable_text_header?(template)
    header = component(template, 'HEADER')
    header.present? && header['text'].to_s.include?('{{')
  end

  def parameterized_button?(template)
    buttons = component(template, 'BUTTONS')&.fetch('buttons', nil) || []
    buttons.any? do |button|
      button['type'].to_s.casecmp('copy_code').zero? ||
        (button['type'].to_s.casecmp('url').zero? && button['url'].to_s.include?('{{'))
    end
  end

  def render_template_body(template, values)
    template_body(template).gsub(/\{\{(.*?)\}\}/) { values[Regexp.last_match(1).strip].to_s }
  end
end
