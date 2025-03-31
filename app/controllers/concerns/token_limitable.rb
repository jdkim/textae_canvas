module TokenLimitable
  extend ActiveSupport::Concern

  included do
    DAILY_TOKEN_LIMIT_PER_CLIENT = 10000
    before_action :check_daily_token_limit, only: %i[create update]
    rescue_from Exceptions::DailyTokenLimitExceededError, with: :handle_daily_token_limit_exceeded
  end

  private

  def token_used_cache_key
    "tokens_used:#{request.remote_ip}:#{Date.current}"
  end

  def check_daily_token_limit
    binding.break
    within_token_limit = Rails.cache.read(token_used_cache_key).to_i <= DAILY_TOKEN_LIMIT_PER_CLIENT
    raise Exceptions::DailyTokenLimitExceededError unless within_token_limit
  end

  def handle_daily_token_limit_exceeded(exception)
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

  def increment_daily_token_usage(token_used)
    current_token_used = Rails.cache.read(token_used_cache_key).to_i
    Rails.cache.write(token_used_cache_key, current_token_used + token_used, expires_in: 24.hours)
  end
end
