class ResponseGenerationService
  attr_reader :ai_client, :redaction_service

  def initialize(ai_client: nil, redaction_service: nil)
    @ai_client = ai_client || AiClients::OpenaiClient
    @redaction_service = redaction_service || PiiRedaction
  end

  def perform(user_query:, data:, context: nil)
    return nil if user_query.blank? || data.blank?

    redacted_query = redact_sensitive_information(user_query)
    system_prompt = build_system_prompt
    user_prompt = build_user_prompt(redacted_query, data, context)

    ai_client.generate_response(system_prompt: system_prompt, user_prompt: user_prompt)
  end

  private

  def format_data(data)
    case data
    when Hash
      data.to_json
    when String
      data
    else
      data.to_s
    end
  end

  def build_user_prompt(user_query, data, context)
    prompt_parts = []
    prompt_parts << "User Query: #{user_query}"
    prompt_parts << "Data: #{format_data(data)}"
    prompt_parts << "Context: #{context}" if context.present?
    prompt_parts.join("\n\n")
  end

  def redact_sensitive_information(user_data)
    @redaction_service.redact(user_data)
  end

  def build_system_prompt
    <<~PROMPT
      You are a helpful benefits assistant. Generate a clear, concise, and friendly response
      based on the provided data. Return a JSON object with:
      - "response": written in plain English
      - "confidence": a float between 0 and 1 indicating confidence in answering the user's question

      The response needs to:
      - Be written in plain English
      - Be accurate and based only on the provided data
      - Include specific amounts, dates, and limits when available
      - Be professional but conversational
      - Not make up any information not in the provided data

      Format your response as a JSON object with a "response" property that is a natural, helpful message to the user and a "confidence" property that is a float between 0 and 1.
    PROMPT
  end
end
