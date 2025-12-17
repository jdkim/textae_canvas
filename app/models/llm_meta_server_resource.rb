class LlmMetaServerResource
  # This is a non-persisted model for fetching external server resources

  class << self
    # Retrieve LLM options available for user selection (API Keys + Ollama)
    # For guest users (no jwt_token), only Ollama is returned
    def available_llm_options(jwt_token)
      options = []

      # Guest user: return only Ollama
      if jwt_token.blank?
        ollama = fetch_ollama(nil)
        return [build_option_from(ollama, type: "ollama")] if ollama
        return options
      end

      # Logged-in user: return API Keys + Ollama
      api_keys = llm_api_keys(jwt_token)

      # Add user's API Keys
      api_keys.each do |key|
        built = build_option_from(key, type: "api_key")
        options << built if built
      end

      # Add Ollama
      ollama = fetch_ollama(jwt_token)
      built_ollama = build_option_from(ollama, type: "ollama")
      options << built_ollama if built_ollama

      options
    end

    private

    def fetch_ollama(jwt_token)
      llms = llms(jwt_token)
      llms.find { |llm| llm["llm_type"] == "ollama" }
    end

    # Builds a normalized option hash from a resource by slicing common keys and merging type
    # Returns nil if resource is nil
    def build_option_from(resource, type:)
      return nil if resource.nil?

      common_keys = %w[uuid description llm_type available_models]
      option = resource.slice(*common_keys)
      # Ensure llm_type for ollama is set to "ollama" even if missing or different
      option["llm_type"] = "ollama" if type == "ollama"
      option.merge(type: type)
    end

    def llms(jwt_token)

      api_url = "#{Rails.configuration.llm_service_base_url}/api/llms"

      headers = { "Content-Type" => "application/json" }
      headers["Authorization"] = "Bearer #{jwt_token}" if jwt_token.present?

      response = HTTParty.get(api_url, headers: headers)

      if response.success?
        response.parsed_response["llms"] || []
      else
        Rails.logger.error "Failed to fetch LLMs: HTTP #{response.code}"
        []
      end
    end

    def llm_api_keys(jwt_token)
      api_url = "#{Rails.configuration.llm_service_base_url}/api/llms_api_keys"

      headers = { "Content-Type" => "application/json" }
      headers["Authorization"] = "Bearer #{jwt_token}"

      response = HTTParty.get(api_url, headers: headers)

      if response.success?
        response.parsed_response["llm_api_keys"] || []
      else
        Rails.logger.error "Failed to fetch LLM API keys: HTTP #{response.code}"
        []
      end
    end
  end
end
