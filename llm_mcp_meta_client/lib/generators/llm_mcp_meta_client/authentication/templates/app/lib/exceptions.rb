module Exceptions
  class TokenLimitExceededError < StandardError
    def initialize(msg = "Daily AI annotate limit reached. Please try again tomorrow.")
      super(msg)
    end
  end

  class OllamaUnavailableError < StandardError
    def initialize(msg = "Ollama is not available in LLM service. Please contact the administrator.")
      super(msg)
    end
  end
end
