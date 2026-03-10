import { throwErrorMessage } from 'dashboard/store/utils/api';
import ConversationApi from '../../../../api/inbox/conversation';
import mutationTypes from '../../../mutation-types';

export default {
  markMessagesRead: async ({ commit }, data) => {
    const { id } = data;

    // atualização otimista (instantânea)
    commit(mutationTypes.UPDATE_MESSAGE_UNREAD_COUNT, {
      id,
      unreadCount: 0,
    });

    try {
      const {
        data: { agent_last_seen_at: lastSeen },
      } = await ConversationApi.markMessageRead(data);

      commit(mutationTypes.UPDATE_MESSAGE_UNREAD_COUNT, {
        id,
        lastSeen,
      });
    } catch (error) {
      throwErrorMessage(error);
    }
  },

  markMessagesUnread: async ({ commit }, { id }) => {
    try {
      const {
        data: { agent_last_seen_at: lastSeen, unread_count: unreadCount },
      } = await ConversationApi.markMessagesUnread({ id });

      commit(mutationTypes.UPDATE_MESSAGE_UNREAD_COUNT, {
        id,
        lastSeen,
        unreadCount,
      });
    } catch (error) {
      throwErrorMessage(error);
    }
  },
};