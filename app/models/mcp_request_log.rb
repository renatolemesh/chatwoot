# Registro de auditoria das chamadas feitas ao servidor MCP (ChatGPT e afins).
class McpRequestLog < ApplicationRecord
  belongs_to :account, optional: true
  belongs_to :user, optional: true

  validates :tool_name, presence: true
  validates :status, presence: true
end
