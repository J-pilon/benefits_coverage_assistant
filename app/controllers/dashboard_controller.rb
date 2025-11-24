class DashboardController < ApplicationController
  def index
    @profile = current_profile
  end

  def create_message
    @profile = current_profile

    user_message = params[:message]

    if user_message.blank?
      render json: { error: "Message cannot be blank" }, status: :unprocessable_entity
      return
    end

    ai_service = AiService.new
    result = ai_service.process_query(user_message, profile: @profile)

    if result && result[:response].present?
      render json: result.compact
    else
      render json: { error: "Failed to process message" }, status: :unprocessable_entity
    end
  end
end
