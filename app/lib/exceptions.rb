module Exceptions
  class TokenLimitExceededError < StandardError
    def initialize(msg = "Daily AI annotate limit reached. Please try again tomorrow.")
      super(msg)
    end
  end

  class RelationCrossesChunkError < StandardError; end
end
