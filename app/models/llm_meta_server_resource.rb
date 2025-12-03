class LlmMetaServerResource
  # This is a non-persisted model for fetching external server resources

  def self.llms(current_user)
    api_url = ENV.fetch("LLMS_URL", "http://localhost:3000/api/llms")
    jwt_token = current_user.id_token
    raise ArgumentError, "User ID token is missing or invalid" if jwt_token.blank?

    headers = { "Content-Type" => "application/json" }
    headers["Authorization"] = "Bearer #{jwt_token}"

    response = HTTParty.get(api_url, headers: headers)

    if response.success?
      response.parsed_response["llms"] || []
    else
      Rails.logger.error "Failed to fetch LLMs: HTTP #{response.code}"
      []
    end
  end

  def self.llm_api_keys(current_user)
    api_url = ENV.fetch("LLM_API_KEYS_URL", "http://localhost:3000/api/llm_api_keys")
    jwt_token = current_user.id_token
    raise ArgumentError, "User ID token is missing or invalid" if jwt_token.blank?

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

  # Retrieve LLM options available for user selection (API Keys + Ollama)
  def self.available_llm_options(current_user)
    llms = self.llms(current_user)
    api_keys = self.llm_api_keys(current_user)

    options = []

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
end
