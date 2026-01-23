import { Controller } from "@hotwired/stimulus"

// Shows/hides the parent entity selector based on fiscal_autonomy selection
export default class extends Controller {
  static targets = ["autonomySelect", "parentField"]

  connect() {
    this.updateParentVisibility()
  }

  autonomyChanged() {
    this.updateParentVisibility()
  }

  updateParentVisibility() {
    const selectedValue = this.autonomySelectTarget.value

    if (selectedValue === "dependent") {
      this.parentFieldTarget.classList.remove("hidden")
    } else {
      this.parentFieldTarget.classList.add("hidden")
    }
  }
}
