module BenefitsCoverageAssistant
  class Error < StandardError; end
  class AiServiceError < Error; end
  class FunctionValidationError < Error; end
  class FunctionNotFoundError < Error; end
  class FunctionDisabledError < Error; end
  class FunctionContextMissingError < Error; end
end
