class AiAnnotationsController < ApplicationController
  before_action :authenticate_user!, except: [ :new ]

  def index
    @ai_annotations = AiAnnotation.where(user: current_user)
  end

  def new
    @new_ai_annotation = AiAnnotation.new
    @history = AiAnnotation.order(created_at: :desc).limit(10)
    fetch_llm_api_keys
  end

  def create
    text = ai_annotation_params[:text]
    prompt = ai_annotation_params[:prompt]
    @new_ai_annotation = AiAnnotation.prepare_with(text, prompt)

    token = current_user.id_token
    selected_api_key_uuid = params[:api_key_uuid]
    selected_model = params[:model]

    ai_annotation = @new_ai_annotation.annotate! token, selected_api_key_uuid, selected_model

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
    fetch_llm_api_keys
  end

  def update
    @ai_annotation = AiAnnotation.find_by(uuid: params[:uuid])
    return redirect_to root_path unless @ai_annotation

    @history = AiAnnotation.order(created_at: :desc).limit(10)
    @ai_annotation.annotation = JSON.parse(ai_annotation_params[:content])
    @ai_annotation.prompt = ai_annotation_params[:prompt]

    token = current_user.id_token
    selected_api_key_uuid = params[:api_key_uuid]
    selected_model = params[:model]

    ai_annotation = @ai_annotation.annotate! token, selected_api_key_uuid, selected_model

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

  def fetch_llm_api_keys
    if user_signed_in?
      begin
        @llm_api_keys = LlmMetaServerResource.llm_api_keys current_user
      rescue ActionController::ParameterMissing
        Rails.logger.error "User ID token is missing or invalid"
        flash.now[:alert] = "Unable to fetch API keys due to missing or invalid user."
      end
    else
      Rails.logger.info "Login required for paid models"
      flash.now[:info] = "Login is required to use paid models."
      @llm_api_keys = []
    end
  end

  def ai_annotation_params
    params.expect(ai_annotation: [ :text, :prompt, :content, :api_key_uuid, :model ])
  end
end
