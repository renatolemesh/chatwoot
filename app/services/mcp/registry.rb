# Catálogo das ferramentas expostas pelo servidor MCP do Connect.
class Mcp::Registry
  VERSION = '1.0.0'.freeze

  TOOLS = [
    Mcp::Tools::ListarConversas,
    Mcp::Tools::LerConversa,
    Mcp::Tools::BuscarContato,
    Mcp::Tools::ListarModelos,
    Mcp::Tools::EnviarMensagem,
    Mcp::Tools::RelatorioResumo,
    Mcp::Tools::RelatorioPor,
    Mcp::Tools::RelatorioAgora
  ].freeze

  class << self
    def schemas
      TOOLS.map(&:schema)
    end

    def fetch(name)
      TOOLS.find { |tool| tool.tool_name == name }
    end
  end
end
