class SupportService
  attr_reader :profile, :ai_service

  def initialize(profile:, ai_service: nil)
    @profile = profile
    @ai_service = ai_service || AiService.new
  end

  def process_user_query(user_message)
    if ai_chat_enabled?
      process_with_ai(user_message)
    else
      create_support_ticket(user_message)
    end
  end

  private

  def process_with_ai(user_message)
    return nil if user_message.blank?

    ai_result = ai_service.process_query(user_message, profile: profile)

    unless ai_result
      return create_support_ticket(
        user_message,
        error: "AI service returned no result"
      )
    end

    ai_metadata = ai_result.merge(source: :ai)
    chat_message = save_chat_message(
      user_message,
      ai_response: ai_result[:response],
      ai_metadata: ai_metadata
    )

    success_response(
      chat_message: chat_message,
      source: :ai
    )
  rescue BenefitsCoverageAssistant::AiServiceError => e
    Rails.logger.error("AI processing failed: #{e.message}")
    create_support_ticket(user_message, error: e.message)
  end

  def create_support_ticket(user_message, error: nil)
    ai_metadata = {
      error: error,
      source: :support_ticket,
      feature_flag_disabled: !ai_chat_enabled?
    }

    chat_message = save_chat_message(
      user_message,
      ai_response: support_ticket_response,
      ai_metadata: ai_metadata
    )

    support_ticket = profile.support_tickets.create!(
      user_question: user_message,
      chat_message: chat_message,
      status: "pending",
      priority: determine_priority(user_message),
      initial_context: {
        error: error,
        ai_disabled: !ai_chat_enabled?,
        source: :chat_interface
      }.compact
    )

    success_response(
      chat_message: chat_message,
      source: :support_ticket,
      ticket: support_ticket
    )
  end

  def save_chat_message(user_message, ai_response: nil, ai_metadata: {})
    ai_metadata[:feature_flag_enabled] = ai_chat_enabled?

    profile.chat_messages.create!(
      user_message: user_message,
      ai_response: ai_response,
      ai_metadata: ai_metadata.compact
    )
  end

  def support_ticket_response
    <<~MESSAGE.strip
      Thanks for your question! Our AI assistant is temporarily unavailable, but I've created a support ticket for you.

      A member of our team will review your question and get back to you within 24 hours.

      You can continue using the chat - all your messages will be saved.
    MESSAGE
  end

  def determine_priority(user_message)
    urgent_keywords = [ "urgent", "emergency", "immediately", "asap", "critical", "now" ]
    high_keywords = [ "important", "soon", "quickly", "need help", "problem" ]

    message_downcase = user_message.downcase

    return "urgent" if urgent_keywords.any? { |word| message_downcase.include?(word) }
    return "high" if high_keywords.any? { |word| message_downcase.include?(word) }

    "normal"
  end

  def success_response(chat_message:, source:, ticket: nil)
    {
      success: true,
      chat_message: {
        id: chat_message.id,
        user_message: chat_message.user_message,
        ai_response: chat_message.ai_response,
        created_at: chat_message.created_at.iso8601
      },
      source: source,
      support_ticket: ticket ? {
        id: ticket.id,
        status: ticket.status,
        priority: ticket.priority
      } : nil
    }.compact
  end

  def ai_chat_enabled?
    FeatureFlags.ai_chat_enabled?
  end
end
