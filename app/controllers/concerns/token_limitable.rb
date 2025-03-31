module TokenLimitable
  extend ActiveSupport::Concern

  included do
    TOKEN_LIMIT = 10000
    before_action :check_token_limit, only: %i[create update]
    rescue_from Exceptions::TokenLimitExceededError, with: :handle_token_limit_exceeded
  end

  private

  # Currently, token limits are reset on a date basis.
  # This is implemented by including the date in the cache key.
  def token_used_cache_key
    "tokens_used:#{request.remote_ip}:#{Date.current}"
  end

  def check_token_limit
    within_token_limit = Rails.cache.read(token_used_cache_key).to_i <= TOKEN_LIMIT
    raise Exceptions::TokenLimitExceededError unless within_token_limit
  end

  def handle_token_limit_exceeded(exception)
    flash.now[:alert] = exception.message

    case action_name
    when "create"
      @new_ai_annotation = AiAnnotation.prepare_with(ai_annotation_params[:text], ai_annotation_params[:prompt])
      render :new, status: :too_many_requests
    when "update"
      @ai_annotation = AiAnnotation.find_by(uuid: params[:id])
      render :edit, status: :too_many_requests
    end
  end

  def increment_token_usage(token_used)
    current_token_used = Rails.cache.read(token_used_cache_key).to_i
    Rails.cache.write(token_used_cache_key, current_token_used + token_used, expires_in: 24.hours)
  end
end
