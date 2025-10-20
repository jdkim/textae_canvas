class AiAnnotationsController < ApplicationController
  include TokenLimitable

  def new
    @new_ai_annotation = AiAnnotation.new
    @history = AiAnnotation.order(created_at: :desc).limit(10)
  end

  def create
    text = ai_annotation_params[:text]
    prompt = ai_annotation_params[:prompt]
    @new_ai_annotation = AiAnnotation.prepare_with(text, prompt)

    begin
      ai_annotation = @new_ai_annotation.annotate!
    rescue Exceptions::RelationOutOfRangeError => e
      ai_annotation = @new_ai_annotation.annotate!(force: true)
    end

    if ai_annotation.nil?
      @dialog_message = "The relationship was lost when Annotation Canvas split the string and queried the LLM. Do you want to proceed?"
      @dialog_buttons = [
        { label: "Force", value: :force },
        { label: "Cancel", value: :cancel }
      ]
      @dialog_opened = true

      @new_ai_annotation.annotation = SimpleInlineTextAnnotation.generate(JSON.parse(ai_annotation_params[:content]))
      @content = JSON.parse(ai_annotation_params[:content], symbolize_names: true).deep_stringify_keys
      @prompt = ai_annotation_params[:prompt]
      # If annotate! returns nil (when dialog is shown), re-render the edit view
      render :edit, status: :unprocessable_entity
      return
    end

    increment_token_usage(@new_ai_annotation.token_used)
    redirect_to "/ai_annotations/#{ai_annotation.uuid}"
  rescue => e
    Rails.logger.error "Error: #{e.message}"
    flash.now[:alert] = "Unexpected error occurred while generating AI annotation."
    render :new, status: :unprocessable_entity
  end

  def edit
    @ai_annotation = AiAnnotation.find_by!(uuid: params[:uuid])
    @history = AiAnnotation.order(created_at: :desc).limit(10)
  end

  def update
    @ai_annotation = AiAnnotation.find_by(uuid: params[:uuid])
    @history = AiAnnotation.order(created_at: :desc).limit(10)
    content = ai_annotation_params[:content]
    annotation_json = JSON.parse(content)
    @ai_annotation.annotation = annotation_json
    @ai_annotation.prompt = ai_annotation_params[:prompt]

    # Show a flash message when the cancel button is pressed in the warning dialog
    # Check which button was pressed using individual params
    if params[:btn_cancel].present?
      @ai_annotation.annotation = annotation_json
      @ai_annotation.save
      flash.now[:alert] = "AI annotation generation was cancelled."
      render :edit, status: :unprocessable_entity
      return
    end

    force = params[:btn_force].present?

    begin
      ai_annotation = @ai_annotation.annotate!(force: force)
    rescue Exceptions::RelationOutOfRangeError => e
      if force
        ai_annotation = @ai_annotation.annotate!(force: true)
      else
        @dialog_message = "The relationship was lost when Annotation Canvas split the string and queried the LLM. Do you want to proceed?"
        @dialog_buttons = [
          { label: "Force", value: :force },
          { label: "Cancel", value: :cancel }
        ]
        @dialog_opened = true

        @ai_annotation.annotation = annotation_json
        @content = JSON.generate(annotation_json)
        @prompt = ai_annotation_params[:prompt]
        # If annotate! returns nil (when dialog is shown), re-render the edit view
        render :edit, status: :unprocessable_entity
        return
      end
    end

    increment_token_usage(@ai_annotation.token_used)
    redirect_to "/ai_annotations/#{ai_annotation.uuid}"
  rescue SimpleInlineTextAnnotation::RelationWithoutDenotationError => e
    # Error that may occur in SimpleInlineTextAnnotation when the LLM response is invalid
    Rails.logger.error "#{e.class}: #{e.message}"
    flash.now[:alert] = "Invalid response from AI. Please retry."
    @ai_annotation.reload
    render :edit, status: :unprocessable_entity
  rescue => e
    Rails.logger.error "Error: #{e.message}"
    @ai_annotation ||= AiAnnotation.find_by(uuid: params[:uuid]) || AiAnnotation.new
    flash.now[:alert] = "Unexpected error occurred while generating AI annotation."
    render :edit, status: :unprocessable_entity
  end

  private

  def ai_annotation_params
    params.expect(ai_annotation: [ :text, :prompt, :content, :uuid ])
  end
end
