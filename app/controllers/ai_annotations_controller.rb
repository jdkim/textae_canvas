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

    ai_annotation = @new_ai_annotation.annotate!
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
    @ai_annotation.annotation = JSON.parse(ai_annotation_params[:content])

    @ai_annotation.prompt = ai_annotation_params[:prompt]

    # Show a flash message when the cancel button is pressed in the warning dialog
    # Check which button was pressed using individual params
    if params[:btn_cancel].present?
      @ai_annotation.annotaiton = SimpleInlineTextAnnotation.parse(@ai_annotation.text).deep_stringify_keys.to_s.gsub(" =>", ":")
      @ai_annotation.save
      flash.now[:alert] = "AI annotation generation was cancelled."
      redirect_to "/ai_annotations/#{@ai_annotation.uuid}"
      return
    end

    force = params[:btn_force].present?
    ai_annotation = @ai_annotation.annotate!(force: force)

    if ai_annotation.nil?
      @dialog_message = "The relationship was lost when TextAE Campus split the string and queried the LLM. Do you want to proceed?"
      @dialog_buttons = [
        { label: "Force", value: :force },
        { label: "Cancel", value: :cancel }
      ]
      @dialog_opened = true

      @ai_annotation.annotation = SimpleInlineTextAnnotation.generate(JSON.parse(ai_annotation_params[:content]))
      @content = JSON.parse(ai_annotation_params[:content], symbolize_names: true).deep_stringify_keys
      @prompt = ai_annotation_params[:prompt]
      # annotate!がnilの場合（ダイアログ表示時）はedit画面を再表示
      render :edit, status: :unprocessable_entity
      return
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
