require 'rails_helper'

RSpec.describe AiService do
  let(:profile) { create(:profile) }
  let(:user_query) { "How much massage coverage do I have left?" }
  let(:mock_intent_service) { double("IntentDeterminationService") }
  let(:mock_response_service) { double("ResponseGenerationService") }
  let(:mock_dispatcher_service) { double("FunctionDispatcher") }

  let(:service) do
    described_class.new(
      intent_service: mock_intent_service,
      response_service: mock_response_service,
      dispatcher_service: mock_dispatcher_service
    )
  end

  describe '#process_query' do
    context 'when params are valid' do
      let(:intent_result) do
        {
          function: "coverage_balances_read",
          params: { "category" => "massage" },
          confidence: 0.95
        }
      end

      let(:dispatch_result) do
        { "remaining_amount" => 500.00, "reset_date" => "2024-12-31" }
      end

      let(:response_result) do
        {
          response: "You have $500 remaining in your massage coverage.",
          confidence: 0.85
        }
      end

      before do
        allow(mock_intent_service).to receive(:perform).and_return(intent_result)
        allow(mock_dispatcher_service).to receive(:dispatch).and_return(dispatch_result)
        allow(mock_response_service).to receive(:perform).and_return(response_result)
      end

      it 'calls intent service with user_query' do
        service.process_query(user_query, profile: profile)
        expect(mock_intent_service).to have_received(:perform).with(user_query)
      end

      it 'calls dispatch service with function, params, and context' do
        service.process_query(user_query, profile: profile)

        expect(mock_dispatcher_service).to have_received(:dispatch).with(
          "coverage_balances_read",
          params: { "category" => "massage" },
          context: { profile: profile }
        )
      end

      it 'calls response service with user_query, data, and context' do
        context = { additional: "info" }
        service.process_query(user_query, profile: profile, context: context)

        expect(mock_response_service).to have_received(:perform).with(
          user_query: user_query,
          data: { "remaining_amount" => 500.00, "reset_date" => "2024-12-31" },
          context: context
        )
      end

      it 'returns hash with all expected properties' do
        result = service.process_query(user_query, profile: profile)

        expect(result).to be_a(Hash)
        expect(result).to include(
          function: "coverage_balances_read",
          params: { "category" => "massage" },
          intent_confidence: 0.95,
          function_result: { "remaining_amount" => 500.00, "reset_date" => "2024-12-31" },
          response: "You have $500 remaining in your massage coverage.",
          response_confidence: 0.85
        )
      end
    end

    context 'when params are invalid' do
      context 'when user_query is blank' do
        it 'returns nil for empty string' do
          result = service.process_query("", profile: profile)

          expect(result).to be_nil
        end

        it 'returns nil for nil' do
          result = service.process_query(nil, profile: profile)

          expect(result).to be_nil
        end
      end

      context 'when profile is blank' do
        it 'returns nil' do
          result = service.process_query(user_query, profile: nil)

          expect(result).to be_nil
        end
      end
    end

    context 'when dependent services fail' do
      context 'when intent_service returns error hash' do
        let(:intent_error_result) do
          {
            function: "error",
            params: {},
            confidence: 0.0,
            reason: "Failed to determine intent"
          }
        end

        it 'returns clarification response' do
          allow(mock_intent_service).to receive(:perform).and_return(intent_error_result)

          result = service.process_query(user_query, profile: profile)

          expect(result).to be_a(Hash)
          expect(result[:function]).to eq("error")
          expect(result[:response]).to eq("Failed to determine intent")
        end
      end

      context 'when the intent is not actionable' do
        let(:unknown_intent_result) do
          {
            function: "unknown",
            params: {},
            confidence: 0.3,
            reason: "I'm not sure how to help with that."
          }
        end

        it 'returns hash without calling dispatcher or response service' do
          allow(mock_intent_service).to receive(:perform).and_return(unknown_intent_result)
          allow(mock_dispatcher_service).to receive(:dispatch)

          result = service.process_query(user_query, profile: profile)

          expect(result).to be_a(Hash)
          expect(result[:function]).to eq("unknown")
          expect(result[:response]).to eq("I'm not sure how to help with that.")
          expect(mock_dispatcher_service).not_to have_received(:dispatch)
        end
      end

      context 'when dispatcher service raises an error' do
        let(:intent_result) do
          {
            function: "coverage_balances_read",
            params: { "category" => "massage" },
            confidence: 0.95
          }
        end

        it 'raises the error' do
          allow(mock_intent_service).to receive(:perform).and_return(intent_result)
          allow(mock_dispatcher_service).to receive(:dispatch).and_raise(StandardError.new("Database connection failed"))

          expect {
            service.process_query(user_query, profile: profile)
          }.to raise_error(StandardError, "Database connection failed")
        end
      end

      context 'when response service raises an error' do
        let(:intent_result) do
          {
            function: "coverage_balances_read",
            params: { "category" => "massage" },
            confidence: 0.95
          }
        end

        let(:dispatch_result) do
          { "remaining_amount" => 500.00 }
        end

        it 'raises the error' do
          allow(mock_intent_service).to receive(:perform).and_return(intent_result)
          allow(mock_dispatcher_service).to receive(:dispatch).and_return(dispatch_result)
          allow(mock_response_service).to receive(:perform).and_raise(StandardError.new("AI timeout"))

          expect {
            service.process_query(user_query, profile: profile)
          }.to raise_error(StandardError, "AI timeout")
        end
      end
    end

    context 'when StandardError occurs' do
      it 'raises the error' do
        allow(mock_intent_service).to receive(:perform).and_raise(StandardError.new("Unexpected error"))

        expect {
          service.process_query(user_query, profile: profile)
        }.to raise_error(StandardError, "Unexpected error")
      end
    end
  end
end
