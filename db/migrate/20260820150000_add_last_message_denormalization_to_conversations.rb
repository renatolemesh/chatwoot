# Denormaliza a ultima mensagem de cada conversa em conversations.
#
# O filtro de "nao lidas" (ConversationFinder#filter_by_unread_status e
# FilterService#unread_conversation_ids) resolvia isso com um JOIN LATERAL que
# buscava a ultima mensagem de CADA conversa aberta a cada requisicao. Com 29k
# conversas abertas isso virava ~13k buscas em messages por chamada (~530ms),
# para devolver ~215 linhas, e respondia por 86% do tempo total de banco.
#
# Com as colunas abaixo + o indice parcial, o filtro vira um unico index scan.
class AddLastMessageDenormalizationToConversations < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  BATCH_SIZE = 5_000
  UNREAD_INDEX = :index_conversations_on_unread_filter
  # Precisa bater com a clausula WHERE gerada pelo finder, senao o planner nao
  # consegue provar que a query implica o predicado e ignora o indice parcial.
  UNREAD_PREDICATE = 'status = 0 AND last_message_type = 0 ' \
                     'AND (agent_last_seen_at IS NULL OR agent_last_seen_at < last_activity_at)'.freeze

  def up
    add_column :conversations, :last_message_type, :integer unless column_exists?(:conversations, :last_message_type)
    add_column :conversations, :last_message_content, :text unless column_exists?(:conversations, :last_message_content)
    add_column :conversations, :last_message_at, :datetime unless column_exists?(:conversations, :last_message_at)

    backfill_last_message

    return if index_name_exists?(:conversations, UNREAD_INDEX)

    add_index :conversations, %i[account_id inbox_id],
              name: UNREAD_INDEX, where: UNREAD_PREDICATE, algorithm: :concurrently
  end

  def down
    remove_index :conversations, name: UNREAD_INDEX, algorithm: :concurrently if index_name_exists?(:conversations, UNREAD_INDEX)
    remove_column :conversations, :last_message_at if column_exists?(:conversations, :last_message_at)
    remove_column :conversations, :last_message_content if column_exists?(:conversations, :last_message_content)
    remove_column :conversations, :last_message_type if column_exists?(:conversations, :last_message_type)
  end

  private

  # Em lotes por faixa de id para nao segurar um lock longo na tabela inteira.
  # Conversa sem nenhuma mensagem fica com as colunas NULL, que e exatamente o
  # que o INNER JOIN LATERAL anterior fazia (ela ficava de fora do filtro).
  def backfill_last_message
    min_id, max_id = select_rows('SELECT MIN(id), MAX(id) FROM conversations').first
    return if min_id.blank?

    (min_id.to_i..max_id.to_i).step(BATCH_SIZE) do |lo|
      execute(backfill_sql(lo, lo + BATCH_SIZE - 1))
    end
  end

  def backfill_sql(low_id, high_id)
    <<~SQL.squish
      WITH last_message AS (
        SELECT c.id AS conversation_id,
               m.message_type,
               LEFT(LOWER(BTRIM(m.content, E' \\t\\r\\n')), 512) AS lower_content,
               m.created_at
        FROM conversations c
        JOIN LATERAL (
          SELECT message_type, content, created_at
          FROM messages
          WHERE messages.conversation_id = c.id
            AND messages.account_id = c.account_id
          ORDER BY messages.created_at DESC
          LIMIT 1
        ) m ON TRUE
        WHERE c.id BETWEEN #{low_id.to_i} AND #{high_id.to_i}
      )
      UPDATE conversations c
      SET last_message_type = last_message.message_type,
          last_message_content = last_message.lower_content,
          last_message_at = last_message.created_at
      FROM last_message
      WHERE c.id = last_message.conversation_id
    SQL
  end
end
