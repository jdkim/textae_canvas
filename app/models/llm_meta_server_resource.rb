class LlmMetaServerResource
  # This is a non-persisted model for fetching external server resources

  class << self
    # Retrieve LLM options available for user selection (API Keys + Ollama)
    # For guest users (no jwt_token), only Ollama is returned
    def available_llm_options(jwt_token)
      options = []

      # Guest user: return only Ollama
      if jwt_token.blank?
        llms = llms(nil)
        ollama = llms.find { |llm| llm["llm_type"] == "ollama" }
        if ollama
          options << {
            uuid: ollama["uuid"],
            description: ollama["description"],
            llm_type: "ollama",
            available_models: ollama["available_models"],
            type: "ollama"
          }
        end
        return options
      end

      # Logged-in user: return API Keys + Ollama
      llms = llms(jwt_token)
      api_keys = llm_api_keys(jwt_token)

      # Add user's API Keys
      api_keys.each do |key|
        options << {
          uuid: key["uuid"],
          description: key["description"],
          llm_type: key["llm_type"],
          available_models: key["available_models"],
          type: "api_key"
        }
      end

      # Add Ollama
      ollama = llms.find { |llm| llm["llm_type"] == "ollama" }
      if ollama
        options << {
          uuid: ollama["uuid"],
          description: ollama["description"],
          llm_type: "ollama",
          available_models: ollama["available_models"],
          type: "ollama"
        }
      end

      options
    end

    private

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
