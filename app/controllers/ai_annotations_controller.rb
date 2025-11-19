class AiAnnotationsController < ApplicationController
  before_action :authenticate_user!, except: [ :new ]

  def index
    @ai_annotations = AiAnnotation.where(user: current_user)
  end

  def new
    @new_ai_annotation = AiAnnotation.new
    @history = AiAnnotation.order(created_at: :desc).limit(10)
    @llm_api_keys = LlmMetaServerResource.llm_api_keys current_user
  end

  def create
    text = ai_annotation_params[:text]
    prompt = ai_annotation_params[:prompt]
    @new_ai_annotation = AiAnnotation.prepare_with(text, prompt)

    @selected_api_key_uuid = params[:api_key_uuid]
    @selected_model = params[:model]

    token = current_user.id_token
    ai_annotation = @new_ai_annotation.annotate! token, @selected_api_key_uuid, @selected_model

    redirect_to "/ai_annotations/#{ai_annotation.uuid}"
  rescue => e
    Rails.logger.error "Error: #{e.message}"
    flash.now[:alert] = "Unexpected error occurred while generating AI annotation."

    # Set required variables in case of error
    @history = user_signed_in? ? AiAnnotation.order(created_at: :desc).limit(10) : []

    render :new, status: :unprocessable_entity
  end

  def edit
    @ai_annotation = AiAnnotation.find_by(uuid: params[:uuid])
    unless @ai_annotation
      redirect_to root_path
      return
    end

    @history = AiAnnotation.order(created_at: :desc).limit(10)
    @llm_api_keys = LlmMetaServerResource.llm_api_keys current_user
  end

  def update
    @ai_annotation = AiAnnotation.find_by(uuid: params[:uuid])
    unless @ai_annotation
      redirect_to root_path
      return
    end

    @history = AiAnnotation.order(created_at: :desc).limit(10)
    @ai_annotation.annotation = JSON.parse(ai_annotation_params[:content])
    @ai_annotation.prompt = ai_annotation_params[:prompt]

    @selected_api_key_uuid = params[:api_key_uuid]
    @selected_model = params[:model]

    token = current_user.id_token
    ai_annotation = @ai_annotation.annotate! token, @selected_api_key_uuid, @selected_model

    redirect_to "/ai_annotations/#{ai_annotation.uuid}"
  rescue SimpleInlineTextAnnotation::RelationWithoutDenotationError => e
    # Error that may occur in SimpleInlineTextAnnotation when the LLM response is invalid
    Rails.logger.error "#{e.class}: #{e.message}"

    flash.now[:alert] = "Invalid response from AI. Please retry."
    @ai_annotation.reload
    render :edit, status: :unprocessable_entity
  rescue => e
    Rails.logger.error "Error: #{e.message}"
    flash.now[:alert] = "Unexpected error occurred while generating AI annotation."
    render :edit, status: :unprocessable_entity
  end

  private

  def ai_annotation_params
    params.expect(ai_annotation: [ :text, :prompt, :content, :api_key_uuid, :model ])
  end
end
