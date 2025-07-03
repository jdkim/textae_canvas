class AiAnnotation < ApplicationRecord
  attr_accessor :text, :prompt, :token_used

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

  # Window size (unit: words)
  WINDOW_SIZE = 50

  before_create :clean_old_annotations
  before_create :set_uuid

  scope :old, -> { where("created_at < ?", 1.day.ago) }

  def self.prepare_with(text, prompt)
    instance = new
    instance.text = text
    instance.prompt = prompt
    instance
  end

  def annotate!
    # To reduce the risk of API key leakage, API error logging is disabled by default.
    # If you need to check the error details, enable logging by add argument `log_errors: true` like: OpenAI::Client.new(log_errors: true)
    client = OpenAI::Client.new

    word_chunk = WordChunk.new(WINDOW_SIZE)

    # Split into words while preserving line breaks
    # Split by lines, then split each line by spaces to create an array of words
    chunks = word_chunk.extract_chunks(@text)

    total_tokens_used = 0
    combined_result = ""

    chunks.each_with_index do |chunk, index|
      user_content = "#{chunk}\n\nPrompt:\n#{@prompt}"
      user_content += "\n\n(This is part #{index + 1}. Please annotate this part only.)" if chunks.take(2).size > 1
      response = client.chat(
        parameters: {
          model: "gpt-4o",
          messages: [
            { role: "system", content: FORMAT_SPECIFICATION },
            { role: "user", content: user_content }
          ]
        }
      )

      total_tokens_used += response.dig("usage", "total_tokens").to_i
      result = response.dig("choices", 0, "message", "content")
      combined_result += result
    end

    self.token_used = total_tokens_used
    result = SimpleInlineTextAnnotation.parse(combined_result)
    result = JSON.generate(result)
    AiAnnotation.create!(content: result)
  end

  def text_json=(annotation_json)
    self.text = SimpleInlineTextAnnotation.generate(annotation_json)
  end

  private

  def clean_old_annotations
    AiAnnotation.old.destroy_all
  end

  def set_uuid
    self.uuid = SecureRandom.uuid
  end
end
