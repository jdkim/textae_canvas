Rails.application.routes.draw do
  mount LlmMcpMetaClient::Engine => "/llm_mcp_meta_client"
end
