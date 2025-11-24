module FunctionDispatcher
  class Service
    attr_reader :registry, :config

    def initialize(registry: nil, config: nil)
      @registry = registry || FunctionRegistry.new
      @config = config || Configuration.new

      load_and_register_functions
    end

    def dispatch(function_name, params, context)
      function_name = function_name.to_sym

      function_def = @registry.get(function_name)
      raise BenefitsCoverageAssistant::FunctionNotFoundError, "Function '#{function_name}' not found" if function_def.nil?

      unless function_enabled?(function_def)
        raise BenefitsCoverageAssistant::FunctionDisabledError, "Function '#{function_name}' is disabled"
      end

      validation = function_def.validate_params(params)
      unless validation[:valid]
        raise BenefitsCoverageAssistant::FunctionValidationError, validation[:errors].join("; ")
      end

      if @config.context_required && context[:profile].nil?
        raise BenefitsCoverageAssistant::FunctionContextMissingError, "Profile context is required"
      end

      function_def.execute(params, context: context)
    end

    def sanitized_function_definitions
      all_function_definitions = @registry.all

      all_function_definitions.map do |func_def|
        {
          name: func_def.name,
          description: func_def.description,
          params_schema: func_def.param_schema
        }
      end
    end

    private

    def load_and_register_functions
      function_definitions = FunctionLoader.load_from_yaml(@config.yaml_file_path)
      function_definitions.each { |function_def| @registry.register(function_def) }
    end

    def function_enabled?(function_def)
      return true if @config.enabled_functions == :all

      @config.enabled_functions.include?(function_def.name)
    end
  end
end
