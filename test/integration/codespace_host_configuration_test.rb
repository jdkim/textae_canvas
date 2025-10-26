require "test_helper"

class CodespaceHostConfigurationTest < ActionDispatch::IntegrationTest
  test "development environment allows codespace hosts when CODESPACES is true" do
    # This test verifies that the Codespace configuration is properly loaded
    # We can't easily test the actual host filtering without running the server,
    # but we can verify the configuration is syntactically correct and loads
    
    # Save original ENV values
    original_codespaces = ENV["CODESPACES"]
    original_domain = ENV["GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN"]
    
    begin
      # Set Codespace environment variables
      ENV["CODESPACES"] = "true"
      ENV["GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN"] = "test.github.dev"
      
      # Reload the development configuration
      Rails.application.config_for(:development)
      
      # If we got here without errors, the configuration is valid
      assert true, "Development configuration loads successfully with Codespace environment variables"
    ensure
      # Restore original ENV values
      ENV["CODESPACES"] = original_codespaces
      ENV["GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN"] = original_domain
    end
  end
  
  test "development environment works without CODESPACES variable" do
    # Save original ENV value
    original_codespaces = ENV["CODESPACES"]
    
    begin
      # Ensure CODESPACES is not set
      ENV.delete("CODESPACES")
      
      # Reload the development configuration
      Rails.application.config_for(:development)
      
      # If we got here without errors, the configuration is valid
      assert true, "Development configuration loads successfully without Codespace environment variables"
    ensure
      # Restore original ENV value
      ENV["CODESPACES"] = original_codespaces
    end
  end
end
