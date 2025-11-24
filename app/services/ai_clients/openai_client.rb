require "openai"

module AiClients
  class OpenaiClient < AiClient
    MODEL_NAME = "gpt-4o-mini"

    class << self
      def determine_intent(system_prompt:, user_prompt:)
        return nil if system_prompt.blank? || user_prompt.blank?

        response = call_openai_chat(
          system_prompt: system_prompt,
          user_prompt: user_prompt,
          temperature: 0.3,
          response_format: "json_object"
        )

        parse_response(response, user_prompt)
      rescue OpenAI::Error => e
        Rails.logger.error("OpenAiClient failed to determine intent: #{e}")
        raise BenefitsCoverageAssistant::AiServiceError.new("Our AI service encountered an error. Please try again.")
      end

      def generate_response(system_prompt:, user_prompt:)
        return nil if system_prompt.blank? || user_prompt.blank?

        response = call_openai_chat(
          system_prompt: system_prompt,
          user_prompt: user_prompt,
          temperature: 0.7,
          response_format: "json_object"
        )

        parse_response(response, user_prompt)
      end

      private

      def openai_client
        api_key = Rails.application.credentials.dig(:openai, :api_key)
        raise BenefitsCoverageAssistant::AiServiceError, "OpenAI API key not configured." if api_key.blank?

        @client ||= OpenAI::Client.new(access_token: api_key)
      end

      def call_openai_chat(system_prompt:, user_prompt:, temperature:, response_format: nil)
        parameters = {
          model: MODEL_NAME,
          messages: [
            { role: "system", content: system_prompt },
            { role: "user", content: user_prompt }
          ],
          temperature: temperature
        }

        parameters[:response_format] = { type: response_format } if response_format.present?

        openai_client.chat(parameters: parameters)
      end

      def parse_response(response, user_prompt)
        content = response.dig("choices", 0, "message", "content")

        return nil if content.blank?

        JSON.parse(content, symbolize_names: true)
      rescue JSON::ParserError => e
        Rails.logger.error("Failed to parse AI service response: #{e}")
        nil
      end
    end
  end
end
