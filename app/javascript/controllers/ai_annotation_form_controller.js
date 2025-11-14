import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="ai-annotation-form"
export default class extends Controller {
  static targets = ["text", "prompt", "submit", "model"]

  connect() {
    this.updateSubmitButton()
  }

  apiKeyChanged(event) {
    const selectedValue = event.target.value
    const modelsData = event.target.dataset.models

    if (!selectedValue || !modelsData) {
      this.#clearModelSelect()
      return
    }

    try {
      const allModels = JSON.parse(modelsData)
      const selectedKey = allModels.find((item) => item.value === selectedValue)

      if (selectedKey?.models) {
        this.#populateModelSelect(selectedKey.models)
      } else {
        this.#clearModelSelect()
      }
    } catch (e) {
      console.error("Failed to parse models data:", e)
      this.#clearModelSelect()
    }
  }

  #populateModelSelect(models) {
    if (!this.hasModelTarget) return

    this.modelTarget.innerHTML =
      '<option value="">Please select a model</option>'
    this.modelTarget.disabled = false

    models.forEach((model) => {
      const option = document.createElement("option")
      option.value = model.value
      option.textContent = model.label
      this.modelTarget.appendChild(option)
    })

    this.updateSubmitButton()
  }

  #clearModelSelect() {
    if (!this.hasModelTarget) return

    this.modelTarget.innerHTML =
      '<option value="">Please select API key first</option>'
    this.modelTarget.disabled = true
    this.updateSubmitButton()
  }

  updateSubmitButton() {
    this.submitTarget.disabled = !this.#canSubmit()
  }

  #canSubmit() {
    // Text field and prompt field can be validated using HTML5's required attribute,
    // so we delegate to checkValidity() to utilize standard validation
    const textField = this.hasTextTarget ? this.textTarget : null
    const promptField = this.promptTarget

    // Use HTML5 standard validation
    const basicFieldsValid =
      (!textField || textField.checkValidity()) && promptField.checkValidity()

    // API Key and Model selects require JavaScript validation for the following reasons:
    // 1. Model select is dynamically enabled/disabled based on API Key selection
    // 2. Disabled selects are not validated by checkValidity()
    // 3. The dependency between the two selects (Model cannot be selected without API Key) cannot be expressed with HTML attributes alone
    const apiKeySelect = document.querySelector('select[name="api_key_uuid"]')
    const modelSelect = this.hasModelTarget
      ? this.modelTarget
      : document.querySelector('select[name="model"]')

    const apiKeySelected = apiKeySelect?.value
    const modelSelected = modelSelect?.value && !modelSelect.disabled

    return basicFieldsValid && apiKeySelected && modelSelected
  }
}
