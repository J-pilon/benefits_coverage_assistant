module FunctionDispatcher
  module Executors
    class GetBenefitCoverageExecutor
      class << self
        def call(params, context:)
          profile = context[:profile]

          category = params["category"] || params[:category]
          profile.get_benefit_coverage(category)
        end
      end
    end
  end
end
