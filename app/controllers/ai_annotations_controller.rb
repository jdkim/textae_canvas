class AiAnnotationsController < ApplicationController
  before_action :set_llm_options, only: [ :new, :create, :edit ]
  before_action :initialize_guest_history, unless: :user_signed_in?

  rescue_from Exceptions::OllamaUnavailableError, with: :handle_ollama_unavailable
  rescue_from SimpleInlineTextAnnotation::RelationWithoutDenotationError, with: :handle_invalid_ai_response

  def index
    @ai_annotations = current_user ? AiAnnotation.where(user: current_user) : []
  end

  def new
    @new_ai_annotation = AiAnnotation.new
    @history = get_history
    @active_uuid = @ai_annotation&.uuid || params.dig(:ai_annotation, :branch_from_uuid)
    @is_guest = !user_signed_in?
  end

  def create
    text = ai_annotation_params[:text]
    prompt = ai_annotation_params[:prompt]
    @new_ai_annotation = AiAnnotation.prepare_with(text, prompt, current_user)

    token = current_user&.id_token
    selected_api_key_uuid = params[:api_key_uuid]
    selected_model = params[:model]
    parent = AiAnnotation.find_by(uuid: ai_annotation_params[:branch_from_uuid]) if ai_annotation_params[:branch_from_uuid].present?

    ai_annotation = @new_ai_annotation.annotate! token, selected_api_key_uuid, selected_model, parent: parent

    # Save guest history to session
    save_to_guest_history(ai_annotation.uuid) unless user_signed_in?

    redirect_to edit_ai_annotation_path(ai_annotation.uuid, api_key_uuid: selected_api_key_uuid, model: selected_model)
  rescue => e
    Rails.logger.error "Error: #{e.message}"
    flash.now[:alert] = "Unexpected error occurred while generating AI annotation."

    # Set required variables in case of error
    @history = get_history
    render :new, status: :unprocessable_entity
  end

  def edit
    @ai_annotation = AiAnnotation.find_by(uuid: params[:uuid])
    return redirect_to root_path unless @ai_annotation

    @history = get_history
    @active_uuid = @ai_annotation&.uuid || params.dig(:ai_annotation, :branch_from_uuid)
    @is_guest = !user_signed_in?
  end

  def update
    @ai_annotation = AiAnnotation.find_by(uuid: params[:uuid])
    return redirect_to root_path unless @ai_annotation

    @ai_annotation.annotation = JSON.parse(ai_annotation_params[:content])
    @ai_annotation.prompt = ai_annotation_params[:prompt]

    token = current_user&.id_token
    selected_api_key_uuid = params[:api_key_uuid]
    selected_model = params[:model]
    parent = AiAnnotation.find_by(uuid: ai_annotation_params[:branch_from_uuid]) if ai_annotation_params[:branch_from_uuid].present?

    ai_annotation = @ai_annotation.annotate! token, selected_api_key_uuid, selected_model, parent: parent

    # Save guest history to session
    save_to_guest_history(ai_annotation.uuid) unless user_signed_in?

    redirect_to edit_ai_annotation_path(ai_annotation.uuid, api_key_uuid: selected_api_key_uuid, model: selected_model)
  rescue => e
    Rails.logger.error "Error: #{e.message}"
    flash.now[:alert] = "Unexpected error occurred while generating AI annotation."
    @history = get_history
    render :edit, status: :unprocessable_entity
  end

  private

  def set_llm_options
    @llm_options = LlmMetaServerResource.available_llm_options current_user&.jwt_token
  end

  def handle_ollama_unavailable(exception)
    Rails.logger.error "#{exception.class}: #{exception.message}"
    flash.now[:alert] = exception.message
    @llm_options = []
    # Execute the appropriate action based on the request
    if action_name.in?(%w[new create edit])
      @history = user_signed_in? ? AiAnnotation.history_with_branches(limit: 50) : []
      render action_name == "create" ? :new : action_name, status: :unprocessable_entity
    end
  end

  def handle_invalid_ai_response(exception)
    Rails.logger.error "#{exception.class}: #{exception.message}"
    flash.now[:alert] = "Invalid response from AI. Please retry."
    @ai_annotation&.reload
    @history = user_signed_in? ? AiAnnotation.history_with_branches(limit: 50) : []
    render :edit, status: :unprocessable_entity
  end

  def initialize_guest_history
    session[:guest_ai_annotation_history] ||= []
  end

  def save_to_guest_history(uuid)
    return if uuid.blank?
    session[:guest_ai_annotation_history] ||= []
    session[:guest_ai_annotation_history].unshift(uuid)
    session[:guest_ai_annotation_history].uniq!
    # Limit to latest 50 items
    session[:guest_ai_annotation_history] = session[:guest_ai_annotation_history].first(50)
  end

  def get_history
    if user_signed_in?
      AiAnnotation.history_with_branches(limit: 50, user: current_user)
    else
      guest_uuids = session[:guest_ai_annotation_history] || []
      AiAnnotation.guest_history(guest_uuids, limit: 50)
    end
  end

  def ai_annotation_params
    params.expect(ai_annotation: [ :text, :prompt, :content, :api_key_uuid, :model, :branch_from_uuid ])
  end
end
