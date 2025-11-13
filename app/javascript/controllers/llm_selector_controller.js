import { Controller } from "@hotwired/stimulus"

// LLM API Keys selection controller
// Fetches data from external API (http://localhost:3000/api/llm_api_keys/)
// Note: CORS configuration is required on the external server side
export default class extends Controller {
  static targets = ["apiKeySelect", "modelSelect"]
  static values = { url: String, jwtToken: String }

  connect() {
    this.loadApiKeys()
  }

  async loadApiKeys() {
    try {
      const headers = {
        "Content-Type": "application/json"
      }

      // Add Authorization header if JWT token is available
      if (this.jwtTokenValue) {
        headers.Authorization = `Bearer ${this.jwtTokenValue}`
      }

      const response = await fetch(this.urlValue || "/api/llm_api_keys/", {
        method: "GET",
        mode: "cors",
        headers: headers,
        credentials: "omit" // Do not send credentials for cross-origin requests
      })

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }

      const data = await response.json()
      this.populateApiKeySelect(data.llm_api_keys)
    } catch (error) {
      console.error("Failed to load API keys:", error)
      // Display error message based on error type
      let errorMessage = "Failed to load API keys"
      if (error.message.includes("401")) {
        errorMessage = "Authentication error: JWT token is invalid or expired"
      } else if (error.message.includes("CORS")) {
        errorMessage =
          "CORS configuration error: CORS settings required on external server"
      } else if (error.message.includes("Failed to fetch")) {
        errorMessage =
          "Network error: External API server (localhost:3000) is not running"
      }
      this.apiKeySelectTarget.innerHTML = `<option value="">${errorMessage}</option>`
    }
  }

  populateApiKeySelect(apiKeys) {
    this.apiKeySelectTarget.innerHTML =
      '<option value="">Please select an API key</option>'

    apiKeys.forEach((apiKey) => {
      const option = document.createElement("option")
      option.value = apiKey.uuid
      option.textContent = apiKey.description
      option.dataset.models = JSON.stringify(apiKey.available_models)
      this.apiKeySelectTarget.appendChild(option)
    })
  }

  apiKeyChanged() {
    const selectedOption =
      this.apiKeySelectTarget.options[this.apiKeySelectTarget.selectedIndex]

    if (selectedOption?.dataset.models) {
      const models = JSON.parse(selectedOption.dataset.models)
      this.populateModelSelect(models)
    } else {
      this.clearModelSelect()
    }
  }

  populateModelSelect(models) {
    this.modelSelectTarget.innerHTML =
      '<option value="">Please select a model</option>'
    this.modelSelectTarget.disabled = false

    models.forEach((model) => {
      const option = document.createElement("option")
      option.value = model.value
      option.textContent = model.label
      this.modelSelectTarget.appendChild(option)
    })

    this.updateFormSubmitButton()
  }

  clearModelSelect() {
    this.modelSelectTarget.innerHTML =
      '<option value="">Please select API key first</option>'
    this.modelSelectTarget.disabled = true
    this.updateFormSubmitButton()
  }

  updateFormSubmitButton() {
    // Update the submit button state of the AI annotation form controller
    const formController =
      this.application.getControllerForElementAndIdentifier(
        this.element.closest('[data-controller*="ai-annotation-form"]'),
        "ai-annotation-form"
      )
    if (
      formController &&
      typeof formController.updateSubmitButton === "function"
    ) {
      formController.updateSubmitButton()
    }
  }
}
