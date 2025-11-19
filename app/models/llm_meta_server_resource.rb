class LlmMetaServerResource
  # This is a non-persisted model for fetching external server resources

  def self.llm_api_keys(current_user)
    api_url = ENV.fetch("LLM_API_KEYS_URL", "http://localhost:3000/api/llm_api_keys/")
    jwt_token = current_user.id_token

    headers = { "Content-Type" => "application/json" }
    headers["Authorization"] = "Bearer #{jwt_token}" if jwt_token.present?

    response = HTTParty.get(api_url, headers: headers)

    if response.success?
      response.parsed_response["llm_api_keys"] || []
    else
      Rails.logger.error "Failed to fetch LLM API keys: HTTP #{response.code}"
      []
    end
  rescue => e
    Rails.logger.error "Failed to fetch LLM API keys: #{e.message}"
    []
  end
end

