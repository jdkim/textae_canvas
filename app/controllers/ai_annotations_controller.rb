class AiAnnotationsController < ApplicationController
  before_action :authenticate_user!, except: [ :new ]
  before_action :set_llm_options, only: [ :new, :create, :edit ]

  def index
    @ai_annotations = AiAnnotation.where(user: current_user)
  end

  def new
    @new_ai_annotation = AiAnnotation.new
    @history = AiAnnotation.history_with_branches(limit: 50)
    @active_uuid = @ai_annotation&.uuid || params.dig(:ai_annotation, :branch_from_uuid)
    @is_guest = !user_signed_in?
  end

  def create
    text = ai_annotation_params[:text]
    prompt = ai_annotation_params[:prompt]
    @new_ai_annotation = AiAnnotation.prepare_with(text, prompt)

    token = current_user.id_token if user_signed_in?
    selected_api_key_uuid = params[:api_key_uuid]
    selected_model = params[:model]
    parent = AiAnnotation.find_by(uuid: ai_annotation_params[:branch_from_uuid]) if ai_annotation_params[:branch_from_uuid].present?

    ai_annotation = @new_ai_annotation.annotate! token, selected_api_key_uuid, selected_model, parent: parent

    redirect_to edit_ai_annotation_path(ai_annotation.uuid, api_key_uuid: selected_api_key_uuid, model: selected_model)
  rescue => e
    Rails.logger.error "Error: #{e.message}"
    flash.now[:alert] = "Unexpected error occurred while generating AI annotation."

    # Set required variables in case of error
    @history = user_signed_in? ? AiAnnotation.history_with_branches(limit: 50) : []
    render :new, status: :unprocessable_entity
  end

  def edit
    @ai_annotation = AiAnnotation.find_by(uuid: params[:uuid])
    return redirect_to root_path unless @ai_annotation

    @history = AiAnnotation.history_with_branches(limit: 50)
    @active_uuid = @ai_annotation&.uuid || params.dig(:ai_annotation, :branch_from_uuid)
    @is_guest = !user_signed_in?
  end

  def update
    @ai_annotation = AiAnnotation.find_by(uuid: params[:uuid])
    return redirect_to root_path unless @ai_annotation

    @history = AiAnnotation.history_with_branches(limit: 50)
    @ai_annotation.annotation = JSON.parse(ai_annotation_params[:content])
    @ai_annotation.prompt = ai_annotation_params[:prompt]

    token = current_user.id_token if user_signed_in?
    selected_api_key_uuid = params[:api_key_uuid]
    selected_model = params[:model]
    parent = AiAnnotation.find_by(uuid: ai_annotation_params[:branch_from_uuid]) if ai_annotation_params[:branch_from_uuid].present?

    ai_annotation = @ai_annotation.annotate! token, selected_api_key_uuid, selected_model, parent: parent

    redirect_to edit_ai_annotation_path(ai_annotation.uuid, api_key_uuid: selected_api_key_uuid, model: selected_model)
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

  def set_llm_options
    begin
      @llm_options = LlmMetaServerResource.available_llm_options current_user&.jwt_token
    rescue => e
      Rails.logger.error "Failed to fetch LLM options: #{e.message}"
      flash.now[:alert] = "Unable to fetch LLM options."
      @llm_options = []
    end
  end

  def ai_annotation_params
    params.expect(ai_annotation: [ :text, :prompt, :content, :api_key_uuid, :model, :branch_from_uuid ])
  end
end
