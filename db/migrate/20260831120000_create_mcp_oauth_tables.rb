class CreateMcpOauthTables < ActiveRecord::Migration[7.1]
  def change
    create_clients
    create_grants
    create_tokens
  end

  private

  def create_clients
    create_table :mcp_oauth_clients do |t|
      t.string :client_id, null: false
      t.string :client_name
      t.jsonb :redirect_uris, default: [], null: false
      t.timestamps
    end
    add_index :mcp_oauth_clients, :client_id, unique: true
  end

  def create_grants
    create_table :mcp_oauth_grants do |t|
      t.string :code, null: false
      t.string :client_id, null: false
      t.bigint :user_id, null: false
      t.string :redirect_uri, null: false
      t.string :code_challenge, null: false
      t.datetime :expires_at, null: false
      t.datetime :used_at
      t.timestamps
    end
    add_index :mcp_oauth_grants, :code, unique: true
    add_index :mcp_oauth_grants, :expires_at
  end

  def create_tokens
    create_table :mcp_oauth_tokens do |t|
      t.string :token, null: false
      t.string :refresh_token
      t.string :client_id, null: false
      t.bigint :user_id, null: false
      t.datetime :expires_at, null: false
      t.datetime :revoked_at
      t.timestamps
    end
    add_index :mcp_oauth_tokens, :token, unique: true
    add_index :mcp_oauth_tokens, :refresh_token, unique: true
    add_index :mcp_oauth_tokens, :user_id
  end
end
