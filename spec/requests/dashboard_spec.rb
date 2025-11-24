require 'rails_helper'

RSpec.describe "Dashboards", type: :request do
  let!(:profile) { create(:profile) }

  describe "GET /" do
    it "returns http success" do
      get root_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /dashboard/messages" do
    let(:mock_ai_service) { instance_double(AiService) }
    let(:valid_message) { "How much do I have remaining for my vision benefits?" }

    before do
      allow(AiService).to receive(:new).and_return(mock_ai_service)
    end

    context "with valid message and successful AI response" do
      let(:ai_response) do
        {
          function: "coverage_balances_read",
          params: { "category" => "vision" },
          intent_confidence: 0.95,
          function_result: { "remaining_amount" => 200.00 },
          response: "You have $200 remaining in your vision coverage.",
          response_confidence: 0.85
        }
      end

      before do
        allow(mock_ai_service).to receive(:process_query).and_return(ai_response)
      end

      it "returns http success" do
        post dashboard_messages_path, params: { message: valid_message }
        expect(response).to have_http_status(:success)
      end

      it "calls AiService with the message and profile" do
        post dashboard_messages_path, params: { message: valid_message }
        expect(mock_ai_service).to have_received(:process_query).with(valid_message, profile: profile)
      end

      it "returns the AI response as JSON" do
        post dashboard_messages_path, params: { message: valid_message }
        json_response = JSON.parse(response.body, symbolize_names: true)

        expect(json_response[:response]).to eq("You have $200 remaining in your vision coverage.")
        expect(json_response[:function]).to eq("coverage_balances_read")
        expect(json_response[:intent_confidence]).to eq(0.95)
      end
    end

    context "with blank message" do
      before do
        allow(mock_ai_service).to receive(:process_query)
      end

      it "returns unprocessable_entity status for empty string" do
        post dashboard_messages_path, params: { message: "" }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns error message for empty string" do
        post dashboard_messages_path, params: { message: "" }
        json_response = JSON.parse(response.body, symbolize_names: true)

        expect(json_response[:error]).to eq("Message cannot be blank")
      end

      it "returns unprocessable_entity status for nil message" do
        post dashboard_messages_path, params: { message: nil }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "does not call AiService when message is blank" do
        post dashboard_messages_path, params: { message: "" }
        expect(mock_ai_service).not_to have_received(:process_query)
      end
    end

    context "when AiService returns nil" do
      before do
        allow(mock_ai_service).to receive(:process_query).and_return(nil)
      end

      it "returns unprocessable_entity status" do
        post dashboard_messages_path, params: { message: valid_message }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns error message" do
        post dashboard_messages_path, params: { message: valid_message }
        json_response = JSON.parse(response.body, symbolize_names: true)

        expect(json_response[:error]).to eq("Failed to process message")
      end
    end

    context "when AiService returns response without response field" do
      let(:incomplete_response) do
        {
          function: "coverage_balances_read",
          params: { "category" => "vision" },
          intent_confidence: 0.95,
          function_result: nil,
          response: nil,
          response_confidence: 0.0
        }
      end

      before do
        allow(mock_ai_service).to receive(:process_query).and_return(incomplete_response)
      end

      it "returns unprocessable_entity status" do
        post dashboard_messages_path, params: { message: valid_message }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns error message" do
        post dashboard_messages_path, params: { message: valid_message }
        json_response = JSON.parse(response.body, symbolize_names: true)

        expect(json_response[:error]).to eq("Failed to process message")
      end
    end
  end
end
