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

    # Split into words while preserving line breaks
    # Split by lines, then split each line by spaces to create an array of words
    words_with_newlines = []
    @text.each_line do |line|
      line_words = line.split(/\s+/)
      # Add line break information to the last word of each line (only line break for empty lines)
      if line_words.empty?
        words_with_newlines << "\n"
      else
        line_words[-1] = "#{line_words[-1]}\n" unless line.chomp == line
        words_with_newlines.concat(line_words)
      end
    end

    total_tokens_used = 0
    combined_result = ""

    if words_with_newlines.size <= WINDOW_SIZE
      # If text size is within window size, make API call only once
      response = client.chat(
        parameters: {
          model: "gpt-4o",
          messages: [
            { role: "system", content: FORMAT_SPECIFICATION },
            { role: "user", content: "#{@text}\n\nPrompt:\n#{@prompt}" }
          ]
        }
      )
      total_tokens_used = response.dig("usage", "total_tokens").to_i
      combined_result = response.dig("choices", 0, "message", "content")
    else
      # If text size exceeds window size, split and make API calls
      chunks = []
      i = 0
      while i < words_with_newlines.size
        # Extract appropriately sized chunks from the word array
        chunk_words = words_with_newlines[i...[i + WINDOW_SIZE, words_with_newlines.size].min]
        # Concatenate words considering line breaks (determine whether to add spaces)
        chunk_text = ""
        chunk_words.each do |word|
          if word == "\n"
            chunk_text += word
          elsif word.end_with?("\n")
            chunk_text += " #{word}"
          elsif chunk_text.empty? || chunk_text.end_with?("\n")
            chunk_text += word
          else
            chunk_text += " #{word}"
          end
        end
        chunks << chunk_text
        i += WINDOW_SIZE
      end

      chunks.each_with_index do |chunk, index|
        response = client.chat(
          parameters: {
            model: "gpt-4o",
            messages: [
              { role: "system", content: FORMAT_SPECIFICATION },
              { role: "user", content: "#{chunk}\n\nPrompt:\n#{@prompt}\n\n(This is part #{index + 1} of #{chunks.size}. Please annotate this part only.)" }
            ]
          }
        )

        total_tokens_used += response.dig("usage", "total_tokens").to_i
        result = response.dig("choices", 0, "message", "content")
        combined_result += result
      end
    end

    self.token_used = total_tokens_used
    result = SimpleInlineTextAnnotation.parse(combined_result)
    puts combined_result
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
