class AiAnnotationsController < ApplicationController
  before_action :authenticate_user!, except: [ :show, :new ]

  def index
    @ai_annotations = AiAnnotation.where(user: current_user)
  end

  def show
    @ai_annotation = AiAnnotation.find_by(uuid: params[:uuid])
    redirect_to root_path unless @ai_annotation
  end

  def new
    Rails.logger.info "User authenticated: #{user_signed_in?}"
    Rails.logger.info "Current user: #{current_user.inspect}"

    @new_ai_annotation = AiAnnotation.new
    @llm_service_url = "#{Rails.application.config.llm_service_base_url}/api/llm_api_keys/"

    if user_signed_in?
      @jwt_token = current_user.id_token || ""
      Rails.logger.debug "JWT Token in new action: current_user=#{current_user.email}, id_token=#{current_user.id_token.present? ? '[PRESENT]' : '[EMPTY]'}"
    end
    @history = AiAnnotation.order(created_at: :desc).limit(10)
    @llm_api_keys = fetch_llm_api_keys
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

    # エラー時に必要な変数を設定
    @llm_service_url = "#{Rails.application.config.llm_service_base_url}/api/llm_api_keys/"
    @jwt_token = token || current_user.id_token
    @history = user_signed_in? ? AiAnnotation.order(created_at: :desc).limit(10) : []

    render :new, status: :unprocessable_entity
  end

  def edit
    @ai_annotation = AiAnnotation.find_by(uuid: params[:uuid])
    unless @ai_annotation
      redirect_to root_path
      return
    end

    @llm_service_url = "#{Rails.application.config.llm_service_base_url}/api/llm_api_keys/"

    if user_signed_in?
      @jwt_token = current_user.id_token || ""
      Rails.logger.debug "JWT Token in new action: current_user=#{current_user.email}, id_token=#{current_user.id_token.present? ? '[PRESENT]' : '[EMPTY]'}"
    end
    @history = AiAnnotation.order(created_at: :desc).limit(10)
    @llm_api_keys = fetch_llm_api_keys
  end

  def update
    Rails.logger.info "=== UPDATE ACTION CALLED ==="
    Rails.logger.info "All params: #{params.inspect}"

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

    # エラー時に必要な変数を設定
    @llm_service_url = "#{Rails.application.config.llm_service_base_url}/api/llm_api_keys/"
    @jwt_token = token || current_user.id_token

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

  def fetch_llm_api_keys
    api_url = ENV.fetch("LLM_API_KEYS_URL", "http://localhost:3000/api/llm_api_keys/")
    jwt_token = current_user.id_token

    headers = { "Content-Type" => "application/json" }
    headers["Authorization"] = "Bearer #{jwt_token}" if jwt_token.present?

    response = HTTParty.get(api_url, headers: headers)

    if response.success?
      response.parsed_response["llm_api_keys"] || []
    else
      Rails.logger.error "Failed to fetch LLM API keys: HTTP #{response.code}"
      []
    end
  rescue => e
    Rails.logger.error "Failed to fetch LLM API keys: #{e.message}"
    []
  end
end
