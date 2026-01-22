import { Controller } from "@hotwired/stimulus"

// Controls dynamic value field display based on selected metric type
export default class extends Controller {
  static targets = ["metricSelect", "numericField", "textField", "placeholder"]
  static values = {
    metricTypes: Object // { metricId: "numeric" | "text" }
  }

  connect() {
    this.updateFieldVisibility()
  }

  metricChanged() {
    this.updateFieldVisibility()
  }

  updateFieldVisibility() {
    const selectedMetricId = this.metricSelectTarget.value

    if (!selectedMetricId) {
      // No metric selected - show placeholder, hide both fields
      this.showPlaceholder()
      return
    }

    const metricType = this.metricTypesValue[selectedMetricId]

    if (metricType === "text") {
      this.showTextField()
    } else {
      // Default to numeric for unknown or numeric types
      this.showNumericField()
    }
  }

  showPlaceholder() {
    if (this.hasPlaceholderTarget) {
      this.placeholderTarget.classList.remove("hidden")
    }
    if (this.hasNumericFieldTarget) {
      this.numericFieldTarget.classList.add("hidden")
    }
    if (this.hasTextFieldTarget) {
      this.textFieldTarget.classList.add("hidden")
    }
  }

  showNumericField() {
    if (this.hasPlaceholderTarget) {
      this.placeholderTarget.classList.add("hidden")
    }
    if (this.hasNumericFieldTarget) {
      this.numericFieldTarget.classList.remove("hidden")
    }
    if (this.hasTextFieldTarget) {
      this.textFieldTarget.classList.add("hidden")
    }
  }

  showTextField() {
    if (this.hasPlaceholderTarget) {
      this.placeholderTarget.classList.add("hidden")
    }
    if (this.hasNumericFieldTarget) {
      this.numericFieldTarget.classList.add("hidden")
    }
    if (this.hasTextFieldTarget) {
      this.textFieldTarget.classList.remove("hidden")
    }
  }
}
