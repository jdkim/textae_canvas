class AiAnnotationsController < ApplicationController
  DAILY_TOKEN_LIMIT_PER_CLIENT = 10000

  before_action :check_daily_token_limit, only: %i[create update]
  rescue_from Exceptions::DailyTokenLimitExceededError, with: :handle_daily_token_limit_exceeded

  def new
    @new_ai_annotation = AiAnnotation.new
  end

  def create
    text = ai_annotation_params[:text]
    prompt = ai_annotation_params[:prompt]
    @new_ai_annotation = AiAnnotation.prepare_with(text, prompt)

    ai_annotation, token_used = @new_ai_annotation.annotate!
    increment_daily_token_usage(token_used)

    redirect_to "/ai_annotations/#{ai_annotation.uuid}"
  rescue => e
    Rails.logger.error "Error: #{e.message}"
    flash.now[:alert] = "Unexpected error occurred while generating AI annotation."
    render :new, status: :unprocessable_entity
  end

  def edit
    @ai_annotation = AiAnnotation.find_by!(uuid: params[:uuid])
  end

  def update
    @ai_annotation = AiAnnotation.find_by(uuid: params[:id])
    @ai_annotation.text = AnnotationConverter.new.to_inline(ai_annotation_params[:content])
    @ai_annotation.prompt = ai_annotation_params[:prompt]

    ai_annotation, token_used = @ai_annotation.annotate!
    increment_daily_token_usage(token_used)

    redirect_to "/ai_annotations/#{ai_annotation.uuid}"
  rescue => e
    Rails.logger.error "Error: #{e.message}"
    flash.now[:alert] = "Unexpected error occurred while generating AI annotation."
    render :edit, status: :unprocessable_entity
  end

  private

  def ai_annotation_params
    params.require(:ai_annotation).permit(:text, :prompt, :content)
  end

  def token_used_cache_key
    "tokens_used:#{request.remote_ip}:#{Date.current}"
  end

  def check_daily_token_limit
    within_token_limit = Rails.cache.read(token_used_cache_key).to_i <= DAILY_TOKEN_LIMIT_PER_CLIENT
    raise Exceptions::DailyTokenLimitExceededError unless within_token_limit
  end

  def handle_daily_token_limit_exceeded(e)
    flash.now[:alert] = "#{e.message}"

    case action_name
    when "create"
      @new_ai_annotation = AiAnnotation.prepare_with(ai_annotation_params[:text], ai_annotation_params[:prompt])
      render :new, status: :too_many_requests
    when "update"
      @ai_annotation = AiAnnotation.find_by(uuid: params[:id])
      render :edit, status: :too_many_requests
    end
  end

  def increment_daily_token_usage(token_used)
    current_token_used = Rails.cache.read(token_used_cache_key).to_i
    Rails.cache.write(token_used_cache_key, current_token_used + token_used, expires_in: 24.hours)
  end
end
