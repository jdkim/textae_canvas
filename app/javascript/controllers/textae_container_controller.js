import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="textae-container"
export default class extends Controller {
    static targets = [ "editor" ]

  connect() {
    this.editorTarget.classList.add('textae-editor')
    const editor = window.initializeTextAEEditor()
      .find((editor) => editor.id === this.editorTarget.id)

    editor.inspectCallback = (annotation) => {
      document.querySelector('#textae-annotation').value = JSON.stringify(annotation)
    }
  }
}
