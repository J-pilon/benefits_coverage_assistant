require 'rails_helper'

RSpec.describe FunctionDispatcher::Service do
  let(:test_yaml_path) { Rails.root.join("spec", "fixtures", "dispatch_functions.yml").to_s }
  let(:config) do
    FunctionDispatcher::Configuration.new.tap do |c|
      c.yaml_file_path = test_yaml_path
      c.enabled_functions = :all
      c.context_required = true
    end
  end
  let(:service) { described_class.new(config: config) }

  describe '#initialize' do
    it 'loads and registers functions from YAML file' do
      expect(service.registry.all).not_to be_empty
    end

    it 'uses default registry if none provided' do
      service = described_class.new(config: config)
      expect(service.registry).to be_a(FunctionDispatcher::FunctionRegistry)
    end

    it 'uses default config if none provided' do
      service = described_class.new
      expect(service.config).to be_a(FunctionDispatcher::Configuration)
    end

    it 'registers expected functions from fixtures' do
      function_names = service.registry.all.map(&:name)
      expect(function_names).to include(:coverage_balances_read)
      expect(function_names).to include(:coverage_rules_explain)
    end
  end

  describe '#dispatch' do
    let(:profile) { create(:profile) }
    let(:context) { { profile: profile } }

    context 'with valid function and parameters' do
      let!(:balance) do
        create(:coverage_balance,
          profile: profile,
          category: "massage",
          remaining_amount: 500.0,
          reset_date: Date.new(2024, 12, 31))
      end

      it 'successfully dispatches coverage_balances_read' do
        result = service.dispatch(:coverage_balances_read, { category: "massage" }, context)

        expect(result).to be_present
        expect(result[:category]).to eq("massage")
        expect(result[:remaining_amount]).to eq(500.0)
      end

      it 'accepts string function names' do
        result = service.dispatch("coverage_balances_read", { category: "massage" }, context)

        expect(result).to be_present
      end

      it 'accepts string parameter keys' do
        result = service.dispatch(:coverage_balances_read, { "category" => "massage" }, context)

        expect(result[:category]).to eq("massage")
      end

      it 'accepts symbol parameter keys' do
        result = service.dispatch(:coverage_balances_read, { category: "massage" }, context)

        expect(result[:category]).to eq("massage")
      end
    end

    context 'with get_benefit_coverage function' do
      let!(:benefit) do
        create(:benefit,
          category: "vision",
          province: profile.province,
          rule_version_id: "v2024-Q1-002")
      end

      it 'successfully retrieves benefit coverage data' do
        result = service.dispatch(:coverage_rules_explain, { category: "vision" }, context)

        expect(result).to be_present
        expect(result).to have_key("version")
      end
    end

    context 'when function does not exist' do
      it 'raises FunctionNotFoundError' do
        expect {
          service.dispatch(:nonexistent_function, {}, context)
        }.to raise_error(BenefitsCoverageAssistant::FunctionNotFoundError, /not found/)
      end

      it 'includes function name in error message' do
        expect {
          service.dispatch(:invalid_func, {}, context)
        }.to raise_error(BenefitsCoverageAssistant::FunctionNotFoundError, /invalid_func/)
      end
    end

    context 'when function is disabled' do
      let(:config) do
        FunctionDispatcher::Configuration.new.tap do |c|
          c.yaml_file_path = test_yaml_path
          c.enabled_functions = [ :coverage_rules_explain ]
          c.context_required = true
        end
      end

      it 'raises FunctionDisabledError for disabled function' do
        expect {
          service.dispatch(:coverage_balances_read, { category: "massage" }, context)
        }.to raise_error(BenefitsCoverageAssistant::FunctionDisabledError, /disabled/)
      end

      let(:create_coverage_balance_for_massage) { create(:benefit, category: "massage", province: profile.province) }

      it 'allows dispatching enabled functions' do
        create_coverage_balance_for_massage

        result = service.dispatch(:coverage_rules_explain, { category: "massage" }, context)

        expect(result).to be_present
      end
    end

    context 'with parameter validation' do
      it 'raises error when required parameter is missing' do
        expect {
          service.dispatch(:coverage_balances_read, {}, context)
        }.to raise_error(BenefitsCoverageAssistant::FunctionValidationError, /Missing required parameters.*category/)
      end

      it 'raises error for invalid enum value' do
        expect {
          service.dispatch(:coverage_balances_read, { category: "invalid_category" }, context)
        }.to raise_error(BenefitsCoverageAssistant::FunctionValidationError, /Invalid value/)
      end

      let(:create_coverage_balance_for_dental) { create(:coverage_balance, profile: profile, category: "dental") }

      it 'accepts valid enum values' do
        create_coverage_balance_for_dental

        result = service.dispatch(:coverage_balances_read, { category: "dental" }, context)

        expect(result).to be_present
      end

      it 'validates all allowed enum values' do
        %w[massage vision dental].each do |category|
          create(:coverage_balance, profile: profile, category: category)
          result = service.dispatch(:coverage_balances_read, { category: category }, context)
          expect(result).to be_present
        end
      end
    end

    context 'with context requirements' do
      it 'raises error when profile context is missing' do
        expect {
          service.dispatch(:coverage_balances_read, { category: "massage" }, {})
        }.to raise_error(BenefitsCoverageAssistant::FunctionContextMissingError, /Profile context is required/)
      end

      it 'raises error when context is nil' do
        expect {
          service.dispatch(:coverage_balances_read, { category: "massage" }, { profile: nil })
        }.to raise_error(BenefitsCoverageAssistant::FunctionContextMissingError, /Profile context is required/)
      end

      let(:create_coverage_balance_for_massage) { create(:coverage_balance, profile: profile, category: "massage") }

      it 'succeeds when context is properly provided' do
        create_coverage_balance_for_massage

        result = service.dispatch(:coverage_balances_read, { category: "massage" }, context)

        expect(result).to be_present
      end
    end

    context 'when context_required is false' do
      let(:config) do
        FunctionDispatcher::Configuration.new.tap do |c|
          c.yaml_file_path = test_yaml_path
          c.enabled_functions = :all
          c.context_required = false
        end
      end

      it 'allows dispatch without profile context but executor raises NoMethodError' do
        # This will still fail at executor level but won't fail at service validation
        expect {
          service.dispatch(:coverage_balances_read, { category: "massage" }, {})
        }.to raise_error(NoMethodError)
      end
    end

    context 'with execution errors' do
      it 'raises executor errors' do
        allow(FunctionDispatcher::Executors::GetCoverageBalanceExecutor)
          .to receive(:call).and_raise(StandardError.new("Database error"))

        expect {
          service.dispatch(:coverage_balances_read, { category: "massage" }, context)
        }.to raise_error(StandardError, "Database error")
      end

      it 'returns nil when data not found' do
        # Profile has no balance for this category
        result = service.dispatch(:coverage_balances_read, { category: "massage" }, context)

        expect(result).to be_nil
      end
    end
  end

  describe '#sanitized_function_definitions' do
    it 'returns array of function definitions' do
      definitions = service.sanitized_function_definitions

      expect(definitions).to be_an(Array)
      expect(definitions).not_to be_empty
    end

    it 'includes function name for each definition' do
      definitions = service.sanitized_function_definitions

      definitions.each do |def_hash|
        expect(def_hash).to have_key(:name)
        expect(def_hash[:name]).to be_present
      end
    end

    it 'includes description for each definition' do
      definitions = service.sanitized_function_definitions

      definitions.each do |def_hash|
        expect(def_hash).to have_key(:description)
        expect(def_hash[:description]).to be_a(String)
      end
    end

    it 'includes params_schema for each definition' do
      definitions = service.sanitized_function_definitions

      definitions.each do |def_hash|
        expect(def_hash).to have_key(:params_schema)
      end
    end

    it 'returns expected function names' do
      definitions = service.sanitized_function_definitions
      names = definitions.map { |d| d[:name] }

      expect(names).to include(:coverage_balances_read)
      expect(names).to include(:coverage_rules_explain)
    end

    it 'includes parameter schema with properties' do
      definitions = service.sanitized_function_definitions
      balance_def = definitions.find { |d| d[:name] == :coverage_balances_read }

      expect(balance_def[:params_schema]).to be_present
      expect(balance_def[:params_schema][:properties]).to have_key(:category)
    end

    it 'includes enum values in schema' do
      definitions = service.sanitized_function_definitions
      balance_def = definitions.find { |d| d[:name] == :coverage_balances_read }

      category_schema = balance_def[:params_schema][:properties][:category]
      expect(category_schema[:enum]).to include("massage", "vision", "dental")
    end
  end

  describe 'integration tests' do
    let(:profile) { create(:profile, province: "ON") }
    let(:context) { { profile: profile } }

    context 'complete workflow for coverage balance query' do
      let(:create_coverage_balance_for_massage) { create(:coverage_balance, profile: profile, category: "massage", remaining_amount: 350.0, reset_date: Date.new(2024, 12, 31), rule_version_id: "v2024-Q1-001") }

      it 'processes balance query from start to finish' do
        # Setup: Create test data
        create_coverage_balance_for_massage

        # Action: Dispatch the function
        result = service.dispatch(:coverage_balances_read, { category: "massage" }, context)

        # Assert: Verify complete result structure
        expect(result).to be_a(Hash)
        expect(result[:category]).to eq("massage")
        expect(result[:remaining_amount]).to eq(350.0)
        expect(result[:reset_date]).to eq(Date.new(2024, 12, 31))
        expect(result[:rule_version_id]).to eq("v2024-Q1-001")
      end
    end

    context 'complete workflow for coverage rules query' do
      let(:create_coverage_balance_for_vision) { create(:benefit, :vision, province: profile.province, category: "vision", rule_version_id: "v2024-Q1-002") }

      it 'processes coverage rules query from start to finish' do
        # Setup: Create benefit with coverage rules
        create_coverage_balance_for_vision

        # Action: Dispatch the function
        result = service.dispatch(:coverage_rules_explain, { category: "vision" }, context)

        # Assert: Verify complete result structure
        expect(result).to be_a(Hash)
        expect(result["version"]).to eq("v2024-Q1-002")
        expect(result["category"]).to eq("vision")
        expect(result["limits"]).to be_present
        expect(result["restrictions"]).to be_present
      end
    end

    context 'handling multiple categories' do
      let(:create_coverage_balance_for_massage) { create(:coverage_balance, profile: profile, category: "massage", remaining_amount: 500.0) }
      let(:create_coverage_balance_for_vision) { create(:coverage_balance, profile: profile, category: "vision", remaining_amount: 150.0) }
      let(:create_coverage_balance_for_dental) { create(:coverage_balance, profile: profile, category: "dental", remaining_amount: 1200.0) }

      it 'dispatches different categories successfully' do
        # Setup multiple balances
        create_coverage_balance_for_massage
        create_coverage_balance_for_vision
        create_coverage_balance_for_dental

        # Test each category
        massage_result = service.dispatch(:coverage_balances_read, { category: "massage" }, context)
        vision_result = service.dispatch(:coverage_balances_read, { category: "vision" }, context)
        dental_result = service.dispatch(:coverage_balances_read, { category: "dental" }, context)

        expect(massage_result[:remaining_amount]).to eq(500.0)
        expect(vision_result[:remaining_amount]).to eq(150.0)
        expect(dental_result[:remaining_amount]).to eq(1200.0)
      end
    end

    context 'error recovery scenarios' do
      let(:create_coverage_balance_for_massage) { create(:coverage_balance, profile: profile, category: "massage", remaining_amount: 300.0) }
      it 'handles missing data gracefully across multiple requests' do
        # Only create one balance
        create_coverage_balance_for_massage

        massage_result = service.dispatch(:coverage_balances_read, { category: "massage" }, context)
        vision_result = service.dispatch(:coverage_balances_read, { category: "vision" }, context)

        expect(massage_result).to be_present
        expect(vision_result).to be_nil
      end


      it 'maintains service state after errors' do
        # First request returns nil
        failed_result = service.dispatch(:coverage_balances_read, { category: "massage" }, context)
        expect(failed_result).to be_nil

        # Create data and retry
        create_coverage_balance_for_massage
        success_result = service.dispatch(:coverage_balances_read, { category: "massage" }, context)

        expect(success_result).to be_present
        expect(success_result[:remaining_amount]).to eq(300.0)
      end
    end

    context 'with different profiles' do
      let(:profile1) { create(:profile, province: "ON") }
      let(:profile2) { create(:profile, province: "QC") }
      let(:create_coverage_balance1) { create(:coverage_balance, profile: profile1, category: "massage", remaining_amount: 500.0) }
      let(:create_coverage_balance2) { create(:coverage_balance, profile: profile2, category: "massage", remaining_amount: 750.0) }

      it 'dispatches correctly for different profiles' do
        create_coverage_balance1
        create_coverage_balance2

        result1 = service.dispatch(:coverage_balances_read, { category: "massage" }, { profile: profile1 })
        result2 = service.dispatch(:coverage_balances_read, { category: "massage" }, { profile: profile2 })

        expect(result1[:remaining_amount]).to eq(500.0)
        expect(result2[:remaining_amount]).to eq(750.0)
      end
    end
  end
end
