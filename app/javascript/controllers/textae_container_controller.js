import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="textae-container"
export default class extends Controller {
  connect() {
    this.element.querySelector('#ai-textae-editor').classList.add('textae-editor')
    const editor = window.initializeTextAEEditor()
      .find((editor) => editor.id === 'ai-textae-editor')

    editor.inspectCallback = (annotation) => {
      document.querySelector('#textae-annotation').value = JSON.stringify(annotation)
    }
  }
}
