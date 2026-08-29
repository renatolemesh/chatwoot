# Erro de negócio das ferramentas MCP. A mensagem é devolvida ao cliente (ChatGPT)
# como conteúdo do tool result, sem virar erro de protocolo JSON-RPC.
class Mcp::Error < StandardError; end
