class OpenAiAnnotator
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

  def call(user_content)
    Rails.logger.info "Request to AI: \n===>\n#{user_content}\n===>" if Rails.env.development?

    # To reduce the risk of API key leakage, API error logging is disabled by default.
    # If you need to check the error details, enable logging by add argument `log_errors: true` like: OpenAI::Client.new(log_errors: true)
    client = OpenAI::Client.new
    parameters = {
      model: "gpt-4o",
      messages: [
        { role: "system", content: FORMAT_SPECIFICATION },
        { role: "user", content: user_content }
      ]
    }

    response = client.chat(parameters: parameters)
    total_tokens = (response.dig("usage", "total_tokens") || 0).to_i
    content = response.dig("choices", 0, "message", "content") || ""

    Rails.logger.info "Response from AI: \n<===\n#{content}\n<===" if Rails.env.development?

    [
      total_tokens,
      content
    ]
  end
end
