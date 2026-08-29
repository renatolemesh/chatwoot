class CreateMcpRequestLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :mcp_request_logs do |t|
      t.bigint :account_id
      t.bigint :user_id
      t.string :tool_name, null: false
      t.jsonb :arguments, default: {}, null: false
      t.string :status, null: false
      t.text :error_message
      t.integer :duration_ms
      t.timestamps
    end

    add_index :mcp_request_logs, [:account_id, :created_at]
    add_index :mcp_request_logs, :user_id
  end
end
