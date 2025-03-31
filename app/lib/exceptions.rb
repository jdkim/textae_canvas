module Exceptions
  class DailyTokenLimitExceededError < StandardError
    def initialize(msg = "Daily AI annotate limit reached. Please try again tomorrow.")
      super(msg)
    end
  end
end
