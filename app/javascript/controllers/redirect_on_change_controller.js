import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="redirect-on-change"
export default class extends Controller {
  static values = { param: String }

  // Action: change->redirect-on-change#update
  update(event) {
    const value = event.target.value
    const url = new URL(window.location.href)
    
    if (value) {
      url.searchParams.set(this.paramValue, value)
    } else {
      url.searchParams.delete(this.paramValue)
    }

    // Turbo.visit handles the page reload efficiently
    Turbo.visit(url)
  }
}