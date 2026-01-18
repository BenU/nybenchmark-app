import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["iframe", "pageInput"]

  connect() {
    // Optional: Sync on load if the field already has a value
    if (this.pageInputTarget.value) {
      this.updatePage()
    }
  }

  updatePage() {
    const pageNumber = this.pageInputTarget.value
    if (!pageNumber) return

    const currentSrc = this.iframeTarget.src
    if (!currentSrc) return

    // Strip existing hash to avoid #page=10#page=20
    const cleanSrc = currentSrc.split('#')[0]
    
    // Append new hash
    const newSrc = `${cleanSrc}#page=${pageNumber}`

    // Update only if changed to avoid iframe flicker loops
    if (this.iframeTarget.src !== newSrc) {
      this.iframeTarget.src = newSrc
    }
  }
}