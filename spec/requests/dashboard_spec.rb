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
    let(:valid_message) { "How much do I have remaining for my vision benefits?" }

    context "with valid message and successful AI response" do
      before do
        allow(FeatureFlags).to receive(:ai_chat_enabled?).and_return(true)
      end

      it "returns http success" do
        post dashboard_messages_path, params: { message: valid_message }
        expect(response).to have_http_status(:success)
      end

      it "creates a chat message" do
        expect {
          post dashboard_messages_path, params: { message: valid_message }
        }.to change(ChatMessage, :count).by(1)
      end

      it "returns the chat message with AI response" do
        post dashboard_messages_path, params: { message: valid_message }
        json_response = JSON.parse(response.body, symbolize_names: true)

        expect(json_response[:user_message]).to eq(valid_message)
        expect(json_response[:ai_response]).to be_present
        expect(json_response[:source]).to eq("ai")
        expect(json_response[:id]).to be_present
        expect(json_response[:created_at]).to be_present
      end

      it "does not create a support ticket" do
        expect {
          post dashboard_messages_path, params: { message: valid_message }
        }.not_to change(SupportTicket, :count)
      end
    end

    context "with blank message" do
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

      it "does not create a chat message when blank" do
        expect {
          post dashboard_messages_path, params: { message: "" }
        }.not_to change(ChatMessage, :count)
      end
    end

    context "when AI chat is disabled" do
      before do
        allow(FeatureFlags).to receive(:ai_chat_enabled?).and_return(false)
      end

      it "returns http success" do
        post dashboard_messages_path, params: { message: valid_message }
        expect(response).to have_http_status(:success)
      end

      it "creates a support ticket" do
        expect {
          post dashboard_messages_path, params: { message: valid_message }
        }.to change(SupportTicket, :count).by(1)
      end

      it "returns support ticket response" do
        post dashboard_messages_path, params: { message: valid_message }
        json_response = JSON.parse(response.body, symbolize_names: true)

        expect(json_response[:user_message]).to eq(valid_message)
        expect(json_response[:ai_response]).to include("support ticket")
        expect(json_response[:source]).to eq("support_ticket")
        expect(json_response[:support_ticket_id]).to be_present
        expect(json_response[:support_ticket_status]).to eq("pending")
      end
    end

    context "when AiService returns nil" do
      let(:mock_ai_service) { instance_double(AiService) }

      before do
        allow(FeatureFlags).to receive(:ai_chat_enabled?).and_return(true)
        allow(AiService).to receive(:new).and_return(mock_ai_service)
        allow(mock_ai_service).to receive(:process_query).and_return(nil)
      end

      it "returns http success with support ticket fallback" do
        post dashboard_messages_path, params: { message: valid_message }
        expect(response).to have_http_status(:success)
      end

      it "creates a support ticket as fallback" do
        expect {
          post dashboard_messages_path, params: { message: valid_message }
        }.to change(SupportTicket, :count).by(1)
      end

      it "returns support ticket response" do
        post dashboard_messages_path, params: { message: valid_message }
        json_response = JSON.parse(response.body, symbolize_names: true)

        expect(json_response[:ai_response]).to include("support ticket")
        expect(json_response[:source]).to eq("support_ticket")
        expect(json_response[:support_ticket_id]).to be_present
      end
    end
  end
end
