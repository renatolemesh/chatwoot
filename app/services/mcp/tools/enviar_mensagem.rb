class Mcp::Tools::EnviarMensagem < Mcp::Tools::Base
  include Mcp::Templates

  class << self
    def tool_name
      'enviar_mensagem'
    end

    def description
      'Envia uma resposta em uma conversa do Connect pelo fluxo normal do produto: ' \
        'a mensagem sai pelo canal do cliente e fica registrada no histórico. Confirme o texto com o usuário antes de enviar. ' \
        'Texto livre só funciona dentro da janela de atendimento (ver pode_responder em ler_conversa); ' \
        'fora dela use o parâmetro modelo, com um dos modelos devolvidos por listar_modelos.'
    end

    def input_schema
      {
        'type' => 'object',
        'properties' => {
          'conversation_id' => { 'type' => 'integer', 'description' => 'ID da conversa que receberá a resposta.' },
          'mensagem' => { 'type' => 'string', 'description' => 'Texto da mensagem. Obrigatório quando não for envio de modelo.' },
          'modelo' => modelo_property,
          'nota_interna' => {
            'type' => 'boolean',
            'description' => 'Quando true, registra uma nota privada visível apenas para a equipe. Padrão: false.'
          }
        }.merge(account_id_property),
        'required' => ['conversation_id']
      }
    end

    def modelo_property
      {
        'type' => 'object',
        'description' => 'Modelo aprovado do WhatsApp oficial, necessário fora da janela de atendimento.',
        'properties' => {
          'nome' => { 'type' => 'string', 'description' => 'Nome do modelo, como aparece em listar_modelos.' },
          'idioma' => { 'type' => 'string', 'description' => 'Idioma do modelo, ex.: pt_BR. Só é preciso se houver mais de um.' },
          'variaveis' => {
            'description' => 'Valores das variáveis: objeto com os nomes ({"data": "17/04"}) ou lista na ordem, se o modelo for posicional.'
          }
        },
        'required' => ['nome']
      }
    end
  end

  def perform
    conversation = find_conversation!(arguments[:conversation_id])
    return send_template(conversation) if arguments[:modelo].present?

    raise Mcp::Error, 'Informe o texto da mensagem ou um modelo.' if arguments[:mensagem].blank?

    ensure_within_reply_window!(conversation) unless private_note?
    deliver(conversation, message_params)
  end

  private

  def send_template(conversation)
    raise Mcp::Error, 'Nota interna não usa modelo; envie apenas o texto.' if private_note?

    template = find_template!(conversation.inbox)
    values = build_values(template)
    deliver(conversation, template_message_params(template, values))
  end

  def deliver(conversation, params)
    message = Messages::MessageBuilder.new(user, conversation, params).perform

    {
      registrada_no_connect: true,
      status_de_entrega: message.status,
      observacao: 'A entrega pelo canal é assíncrona. Confirme o status final com ler_conversa.',
      conversation_id: conversation.display_id,
      canal: conversation.inbox&.name,
      contato: present_contact(conversation.contact),
      mensagem: present_message(message)
    }.compact
  end

  # Canais como o WhatsApp oficial só aceitam texto livre dentro da janela de
  # atendimento; fora dela exigem um modelo aprovado. Sem esta checagem a
  # mensagem seria criada e falharia na entrega.
  def ensure_within_reply_window!(conversation)
    return if conversation.can_reply?

    raise Mcp::Error,
          "A janela de atendimento do canal '#{conversation.inbox&.name}' está fechada: faz tempo demais que o contato não escreve. " \
          'Nesse estado só um modelo aprovado pode ser enviado: use listar_modelos e repita com o parâmetro modelo. ' \
          'Uma nota interna, com nota_interna: true, continua permitida.'
  end

  def find_template!(inbox)
    name = arguments.dig(:modelo, :nome)
    candidates = approved_templates(inbox).select { |template| template['name'] == name }
    raise Mcp::Error, "Modelo '#{name}' não existe ou não está aprovado em '#{inbox.name}'. Consulte listar_modelos." if candidates.empty?

    template = pick_language(candidates, inbox)
    reason = unsupported_template_reason(template)
    raise Mcp::Error, "O modelo '#{name}' #{reason} e precisa ser enviado pela interface do Connect." if reason

    template
  end

  def pick_language(candidates, inbox)
    language = arguments.dig(:modelo, :idioma)
    return candidates.first if language.blank? && candidates.one?
    raise Mcp::Error, ambiguous_language_message(candidates, inbox) if language.blank?

    candidates.find { |template| template['language'].to_s.casecmp(language.to_s).zero? } ||
      raise(Mcp::Error, "O modelo não existe no idioma '#{language}'. Disponíveis: #{candidates.pluck('language').join(', ')}.")
  end

  def ambiguous_language_message(candidates, inbox)
    "O modelo existe em mais de um idioma em '#{inbox.name}': #{candidates.pluck('language').join(', ')}. Informe idioma."
  end

  # Converte o que o assistente mandou para o formato que o
  # Whatsapp::TemplateProcessorService espera.
  def build_values(template)
    expected = template_variables(template)
    return {} if expected.empty?

    given = normalize_given(expected)
    missing = expected - given.keys
    raise Mcp::Error, "Faltam variáveis do modelo '#{template['name']}': #{missing.join(', ')}." if missing.any?

    expected.index_with { |name| given[name].to_s }
  end

  def normalize_given(expected)
    given = arguments.dig(:modelo, :variaveis)
    raise Mcp::Error, "O modelo exige as variáveis: #{expected.join(', ')}." if given.blank?
    return expected.zip(Array(given)).to_h.compact if given.is_a?(Array)

    given.to_h.transform_keys(&:to_s)
  end

  def template_message_params(template, values)
    ActionController::Parameters.new(
      content: render_template_body(template, values),
      message_type: 'outgoing',
      private: false,
      template_params: {
        name: template['name'],
        namespace: template['namespace'].presence,
        category: template['category'].presence,
        language: template['language'].presence,
        processed_params: values.any? ? { body: values } : {}
      }.compact
    )
  end

  def private_note?
    ActiveModel::Type::Boolean.new.cast(arguments[:nota_interna]) || false
  end

  def message_params
    ActionController::Parameters.new(
      content: arguments[:mensagem].to_s,
      message_type: 'outgoing',
      private: private_note?
    )
  end
end
