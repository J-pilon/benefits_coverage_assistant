class AiService
  attr_reader :dispatcher_service, :intent_service, :response_service

  def initialize(dispatcher_service: nil, intent_service: nil, response_service: nil)
    @dispatcher_service = dispatcher_service || FunctionDispatcher
    @intent_service = intent_service || IntentDeterminationService.new
    @response_service = response_service || ResponseGenerationService.new
  end

  def process_query(user_query, profile:, context: nil)
    return nil if user_query.blank? || profile.nil?

    intent_data = determine_intent(user_query)
    return build_clarification_response(intent_data) unless actionable_intent?(intent_data)

    function_result = execute_function(intent_data, profile)
    response_data = generate_response(user_query, function_result, context)

    {
      function: intent_data[:function],
      params: intent_data[:params],
      intent_confidence: intent_data[:confidence],
      function_result: function_result,
      response: response_data&.dig(:response) || "I couldn't find any information for that request.",
      response_confidence: response_data&.dig(:confidence) || 0.0
    }
  end

  private

  def build_clarification_response(intent_data)
    clarification_message = intent_data[:reason] || "I'm not sure how to help with that question."

    {
      function: intent_data[:function],
      params: intent_data[:params],
      intent_confidence: intent_data[:confidence],
      function_result: nil,
      response: clarification_message,
      response_confidence: intent_data[:confidence]
    }
  end

  def actionable_intent?(intent_data)
    intent_data[:function].present? &&
      intent_data[:function] != "unknown" &&
      intent_data[:function] != "error"
  end

  def execute_function(intent_data, profile)
    @dispatcher_service.dispatch(
      intent_data[:function],
      params: intent_data[:params],
      context: { profile: profile }
    )
  end

  def generate_response(user_query, function_result, context)
    @response_service.perform(
      user_query: user_query,
      data: function_result,
      context: context
    )
  end

  def determine_intent(user_query)
    @intent_service.perform(user_query)
  end
end
