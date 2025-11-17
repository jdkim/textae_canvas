class LlmAnnotator
  FORMAT_SPECIFICATION = <<~EOS
    Annotate the text according to the prompt with using the following syntax:

    ## Annotation Format
    - An annotation consists of two consecutive square bracket pairs:
      - First: annotated text
      - Second: label
    - Example: [Annotated Text][Label]

    ## Label Definition (Optional)
    - Labels can be defined as `[Label]: URL`.

    ## Escaping Metacharacters
    - To prevent misinterpretation, escape the first `[` if it naturally occurs.
    - Example: \[Part of][Original Text]

    ## Handling Unknown Prompts
    - If could not understand prompt, return the input text unchanged.

    Output the original text with annotations.
  EOS

  def call(id_token, api_key_uuid, model_id, user_content)
    Rails.logger.info "Request to AI: \n===>\n#{user_content}\n===>" if Rails.env.development?
    response = request(api_key_uuid, id_token, model_id, user_content)
    response_body = response.parsed_response
    content = response_body.dig("response", "message") || ""

    Rails.logger.info "Response from AI: \n<===\n#{content}\n<===" if Rails.env.development?

    content
  end

  private

  def request(api_key_uuid, id_token, model_id, user_content)
    HTTParty.post(
      url(api_key_uuid, model_id),
      headers: {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{id_token}"
      },
      body: { prompt: "#{FORMAT_SPECIFICATION}\n\n#{user_content}" }.to_json
    )
  end

  def url(api_key_uuid, model_id)
    "#{Rails.application.config.llm_service_base_url}/api/llm_api_keys/#{api_key_uuid}/models/#{model_id}/chats"
  end
end
