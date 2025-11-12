# frozen_string_literal: true

# LLM Service Configuration
# External LLM service base URL for API key and model management
Rails.application.configure do
  # LLMサービスのベースURL
  # 環境変数 LLM_SERVICE_BASE_URL から取得、未設定の場合はデフォルト値を使用
  config.llm_service_base_url = ENV.fetch('LLM_SERVICE_BASE_URL', 'http://localhost:3000')
end

