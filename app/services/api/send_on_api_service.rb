class Api::SendOnApiService
  pattr_initialize [:message!]

  def perform
    deliver_via_webhook
    Messages::SendEmailNotificationService.new(message: message).perform
  end

  private

  delegate :inbox, :conversation, to: :message

  def deliver_via_webhook
    return unless webhook_deliverable?

    # Puts the message back into "sending" on a retry so the UI does not briefly flash "sent".
    message.update_column(:status, Message.statuses[:sending]) unless message.sending?

    Webhooks::Trigger.execute(
      inbox.channel.webhook_url,
      payload,
      :api_inbox_webhook,
      delivery_id: SecureRandom.uuid
    )

    message.reload
    # Webhooks::Trigger flips the message to "failed" on error via Messages::StatusUpdateService;
    # if it is still "sending" then the webhook succeeded and we promote it to "sent".
    message.update!(status: :sent) if message.sending?
  end

  def webhook_deliverable?
    message.outgoing? &&
      message.source_id.blank? &&
      inbox.channel_type == 'Channel::Api' &&
      inbox.channel.webhook_url.present?
  end

  def payload
    message.webhook_data.merge(event: 'message_created')
  end
end
