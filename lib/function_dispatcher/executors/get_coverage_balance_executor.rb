module FunctionDispatcher
  module Executors
    class GetCoverageBalanceExecutor
      class << self
        def call(params, context:)
          profile = context[:profile]

          category = params["category"] || params[:category]
          profile.get_coverage_balance(category)
        end
      end
    end
  end
end
