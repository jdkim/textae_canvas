class AiAnnotation < ApplicationRecord
  attr_accessor :text, :token_used

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
    openai_annotator = OpenAiAnnotator.new

    # SimpleInlineTextAnnotation returns keys as symbols
    parameter = SimpleInlineTextAnnotation.parse(@text).deep_stringify_keys

    chunks = TokenChunk.new.from parameter, window_size: 30

    all_chunk_results = []

    total_tokens_used = chunks.each_with_index.reduce(0) do |tokens_sum, (chunk, index)|
      simple_inline_text = SimpleInlineTextAnnotation.generate(chunk)
      user_content = "#{simple_inline_text}\n\nPrompt:\n#{prompt}"
      user_content += "\n\n(This is part #{index + 1}. Please annotate this part only.)" if chunks.size > 1

      adding_tokens_sum, adding_result = openai_annotator.call(user_content)
      # Remove backslashes from OpenAI response
      adding_result = adding_result.gsub("\\", "")

      # SimpleInlineTextAnnotation returns keys as symbols
      begin
        adding_result_as_json = SimpleInlineTextAnnotation.parse(adding_result).deep_stringify_keys
      rescue => e
        # If parsing fails, create an empty result
        adding_result_as_json = { "text" => "", "denotations" => [], "relations" => [] }
      end

      all_chunk_results << adding_result_as_json if adding_result_as_json.present? && adding_result_as_json["text"].present?

      tokens_sum + adding_tokens_sum
    end

    # Merge results from all chunks
    if all_chunk_results.any?
      combined_result = AnnotationMerger.new(all_chunk_results).merged
    else
      combined_result = { "text" => @text, "denotations" => [], "relations" => [] }
    end

    self.token_used = total_tokens_used
    result = JSON.generate(combined_result)
    AiAnnotation.create!(prompt: prompt, content: result)
  end

  def text_json=(annotation_json)
    self.text = SimpleInlineTextAnnotation.generate(annotation_json)
  end

  private

  # Delete old annotations
  def clean_old_annotations
    AiAnnotation.old.destroy_all
  end

  # Set a new UUID
  def set_uuid
    self.uuid = SecureRandom.uuid
  end
end
