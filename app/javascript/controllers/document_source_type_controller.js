import { Controller } from "@hotwired/stimulus"

// Toggles visibility of file upload section based on source_type selection
export default class extends Controller {
  static targets = ["select", "fileSection", "urlHint"]

  connect() {
    this.toggle()
  }

  toggle() {
    const sourceType = this.selectTarget.value

    // Show/hide file upload section
    if (this.hasFileSectionTarget) {
      this.fileSectionTarget.style.display = sourceType === "web" ? "none" : "block"
    }

    // Toggle URL hint text
    if (this.hasUrlHintTarget) {
      const pdfHint = this.urlHintTarget.querySelector('[data-hint-for="pdf"]')
      const webHint = this.urlHintTarget.querySelector('[data-hint-for="web"]')

      if (pdfHint) pdfHint.style.display = sourceType === "pdf" ? "inline" : "none"
      if (webHint) webHint.style.display = sourceType === "web" ? "inline" : "none"
    }
  }
}
