class LlmMetaServerResource
  # This is a non-persisted model for fetching external server resources

  class << self
    # Retrieve LLM options available for user selection (API Keys + Ollama)
    # For guest users (no jwt_token), only Ollama is returned
    def available_llm_options(jwt_token)
      if jwt_token.blank?
        # For guest users
        built_ollama = built_ollama_option
        # return only Ollama
        return built_ollama ? [built_ollama] : []
      end

      # Logged-in user: return API Keys + Ollama
      api_keys = llm_api_keys(jwt_token)

      # Add user's API Keys
      options = api_keys.map { build_option_from(_1, type: "api_key") }
                        .filter { |option| option.present? }

      # Add Ollama
      built_ollama = built_ollama_option
      options << built_ollama if built_ollama

      options
    end

    private

    def built_ollama_option
      ollama = llms.find { |llm| llm["llm_type"] == "ollama" }
      return nil unless ollama
      build_option_from(ollama, type: "ollama")
    end

    # Builds a normalized option hash from a resource by slicing common keys and merging type
    # Returns nil if resource is nil
    def build_option_from(resource, type:)
      common_keys = %w[uuid description llm_type available_models]
      option = resource.slice(*common_keys).symbolize_keys
      # Ensure llm_type for ollama is set to "ollama" even if missing or different
      option[:llm_type] = "ollama" if type == "ollama"
      option.merge(type: type)
    end

    def llms
      api_url = "#{Rails.configuration.llm_service_base_url}/api/llms"

      headers = { "Content-Type" => "application/json" }

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
