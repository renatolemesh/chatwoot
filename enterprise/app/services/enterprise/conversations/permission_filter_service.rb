module Enterprise::Conversations::PermissionFilterService
  def perform
    return filter_by_permissions(permissions) if user_has_custom_role?

    super
  end

  private

  def user_has_custom_role?
    user_role == 'agent' && account_user&.custom_role_id.present?
  end

  def permissions
    account_user&.permissions || []
  end

  def filter_by_permissions(permissions)
    # Permission-based filtering with hierarchy
    # conversation_manage > conversation_unassigned_manage > conversation_participating_manage
    # conversation_team_manage is an additive flag that also includes conversations assigned to the user's teams
    if permissions.include?('conversation_manage')
      accessible_conversations
    elsif permissions.include?('conversation_unassigned_manage')
      filter_unassigned_and_mine(include_team_assigned: permissions.include?('conversation_team_manage'))
    elsif permissions.include?('conversation_participating_manage')
      accessible_conversations.assigned_to(user)
    else
      Conversation.none
    end
  end

  def filter_unassigned_and_mine(include_team_assigned: false)
    user_team_ids = user.teams.where(account_id: account.id).pluck(:id)
    scopes = [
      accessible_conversations.assigned_to(user),
      accessible_conversations.unassigned
                              .where('conversations.team_id IN (?) OR conversations.team_id IS NULL', user_team_ids)
    ]
    scopes << accessible_conversations.where(team_id: user_team_ids) if include_team_assigned

    Conversation.from("(#{scopes.map(&:to_sql).join(' UNION ')}) as conversations")
                .where(account_id: account.id)
  end
end
