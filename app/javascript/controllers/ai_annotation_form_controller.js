import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="ai-annotation-form"
export default class extends Controller {
  static targets = ["text", "prompt", "submit"]

  connect() {
    this.updateSubmitButton()
  }

  updateSubmitButton() {
    this.submitTarget.disabled = !this.element.checkValidity()
  }
}
