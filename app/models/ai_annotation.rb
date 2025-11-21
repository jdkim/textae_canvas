class AiAnnotation < ApplicationRecord
  attr_accessor :annotation, :text

  before_create :clean_old_annotations
  before_create :set_uuid

  scope :old, -> { where("created_at < ?", 1.day.ago) }
  scope :recent, -> { order(created_at: :desc) }

  belongs_to :parent, class_name: "AiAnnotation", optional: true
  has_many :children, class_name: "AiAnnotation", foreign_key: "parent_id"
  belongs_to :user, optional: true

  validate :parent_chain_no_cycle

  def self.prepare_with(text, prompt, user = nil)
    instance = new
    instance.text = text
    instance.prompt = prompt
    instance.user = user if user
    instance
  end

  def self.history_with_branches(limit: 50, user: nil)
    scope = recent.includes(:parent)
    scope = scope.where(user: user) if user
    scope.limit(limit)
  end

  def self.guest_history(uuids, limit: 50)
    return AiAnnotation.none if uuids.blank?
    recent.where(uuid: uuids).limit(limit)
  end

  def annotate!(id_token, api_key_uuid, model_id, parent: nil)
    @id_token = id_token
    @api_key_uuid = api_key_uuid
    @model_id = model_id
    local_parent = parent

    if @annotation.dig("selectedText", "status") == "selected"
      # Get selected range from the annotation
      begin_offset = @annotation.dig("selectedText", "begin").to_i
      end_offset = @annotation.dig("selectedText", "end").to_i
      result = selected_window @annotation, begin_offset, end_offset
    else
      result = sliding_window @annotation
    end

    result = JSON.generate(result)

    AiAnnotation.create!(prompt: prompt, content: result, parent: local_parent, user: self.user)
  end

  def text=(annotation)
    @text = annotation
    @annotation = SimpleInlineTextAnnotation.parse(annotation)
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

  # Annotates the part specified by the user.
  def selected_window(annotation_json, begin_offset, end_offset)
    slicer = AnnotationSlicer.new(annotation_json)
    selected_annotation = slicer.annotation_in(begin_offset..end_offset)
    annotation_text = SimpleInlineTextAnnotation.generate(selected_annotation)

    user_content = "#{annotation_text}\n\nPrompt:\n#{prompt}"

    result = LlmAnnotator.new.call(@id_token, @api_key_uuid, @model_id, user_content)
    result_as_json = SimpleInlineTextAnnotation.parse(result)

    AnnotationMerger.new([
                         slicer.annotation_in(0...begin_offset),
                         result_as_json,
                         slicer.annotation_in(end_offset..annotation_json["text"].length)
                       ]).merged
  end

  def sliding_window(annotation_json)
    chunks = TokenChunk.from annotation_json, window_size: 50
    result = chunks.each_with_object({ token_used: 0, chunk_results: [] })
                   .with_index do |(chunk, results), index|
      annotation_text = SimpleInlineTextAnnotation.generate(chunk)

      user_content = "#{annotation_text}\n\nPrompt:\n#{prompt}"
      user_content += "\n\n(This is part #{index + 1}. Please annotate this part only.)" if chunks.size > 1

      chunk_result = LlmAnnotator.new.call(@id_token, @api_key_uuid, @model_id, user_content)

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

    AnnotationMerger.new(result[:chunk_results]).merged
  end

  def parent_chain_no_cycle
    return if parent.nil?
    ancestor = parent
    while ancestor
      if ancestor == self
        errors.add(:parent, "cannot create a cycle")
        break
      end
      ancestor = ancestor.parent
    end
  end
end
