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
      this.clearModelSelect()
      return
    }

    try {
      const allModels = JSON.parse(modelsData)
      const selectedKey = allModels.find((item) => item.value === selectedValue)

      if (selectedKey && selectedKey.models) {
        this.populateModelSelect(selectedKey.models)
      } else {
        this.clearModelSelect()
      }
    } catch (e) {
      console.error("Failed to parse models data:", e)
      this.clearModelSelect()
    }
  }

  populateModelSelect(models) {
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

  clearModelSelect() {
    if (!this.hasModelTarget) return

    this.modelTarget.innerHTML =
      '<option value="">Please select API key first</option>'
    this.modelTarget.disabled = true
    this.updateSubmitButton()
  }

  updateSubmitButton() {
    const textField = this.hasTextTarget ? this.textTarget.value.trim() : true
    const promptField = this.promptTarget.value.trim()
    const apiKeySelect = document.querySelector('select[name="api_key_uuid"]')
    const modelSelect = this.hasModelTarget
      ? this.modelTarget
      : document.querySelector('select[name="model"]')

    const apiKeySelected = apiKeySelect?.value
    const modelSelected = modelSelect?.value && !modelSelect.disabled

    const isValid = textField && promptField && apiKeySelected && modelSelected

    this.submitTarget.disabled = !isValid
  }
}
