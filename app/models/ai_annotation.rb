class AiAnnotation < ApplicationRecord
  attr_accessor :text, :prompt, :token_used

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
    openai_chat_template = OpenAiChatTemplate.new
    word_chunk = WordChunk.new

    # Extract text chunks using WordChunk class
    chunks = word_chunk.extract_chunks(@text)

    total_tokens_used, combined_result = chunks.each_with_index.reduce([ 0, "" ]) do |(tokens_sum, result), (chunk, index)|
      user_content = "#{chunk}\n\nPrompt:\n#{@prompt}"
      user_content += "\n\n(This is part #{index + 1}. Please annotate this part only.)" if chunks.take(2).size > 1
      openai_chat_template.call(result, tokens_sum, user_content)
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
