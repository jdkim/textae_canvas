class AiAnnotation < ApplicationRecord
  attr_accessor :annotation, :text, :token_used

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
    if @annotation.dig("selectedText", "status") == "selected"
      # Get selected range from the annotation
      begin_offset = @annotation.dig("selectedText", "begin").to_i
      end_offset = @annotation.dig("selectedText", "end").to_i
      selected_annotation = AnnotationSlicer.new(@annotation).annotation_in(begin_offset..end_offset)
      Rails.logger.info selected_annotation.inspect

      combined_result, total_tokens_used = sliding_window @annotation
    else
      combined_result, total_tokens_used = sliding_window @annotation
    end

    self.token_used = total_tokens_used
    result = JSON.generate(combined_result)

    AiAnnotation.create!(prompt: prompt, content: result)
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

  def sliding_window(annotation_json)
    chunks = TokenChunk.from annotation_json, window_size: 50
    result = chunks.each_with_object({ token_used: 0, chunk_results: [] })
                   .with_index do |(chunk, results), index|
      annotation_text = SimpleInlineTextAnnotation.generate(chunk)

      user_content = "#{annotation_text}\n\nPrompt:\n#{prompt}"
      user_content += "\n\n(This is part #{index + 1}. Please annotate this part only.)" if chunks.size > 1

      adding_tokens_sum, chunk_result = OpenAiAnnotator.new.call(user_content)
      results[:token_used] += adding_tokens_sum

      # Remove backslashes from OpenAI response
      chunk_result = chunk_result.gsub("\\", "")

      begin
        adding_result_as_json = SimpleInlineTextAnnotation.parse(chunk_result)
        results[:chunk_results] << adding_result_as_json
      rescue => e
        # Log the error but continue processing other chunks
        Rails.logger.error "Error parsing chunk result: #{e.message}"
      end
    end

    [
      AnnotationMerger.new(result[:chunk_results]).merged,
      result[:token_used]
    ]
  end
end
