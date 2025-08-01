module Exceptions
  class TokenLimitExceededError < StandardError
    def initialize(msg = "Daily AI annotate limit reached. Please try again tomorrow.")
      super(msg)
    end
  end

  class RelationOutOfRangeError < StandardError; end

  class DenotationFragmentedError < StandardError; end

  # This error is raised when the AI response is invalid.
  class InvalidResponseError < StandardError; end
end
