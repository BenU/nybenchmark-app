import { Controller } from "@hotwired/stimulus"

// Shows/hides school-specific fields based on entity kind selection
export default class extends Controller {
  static targets = ["kindSelect", "schoolFields"]

  connect() {
    this.updateSchoolFieldsVisibility()
  }

  kindChanged() {
    this.updateSchoolFieldsVisibility()
  }

  updateSchoolFieldsVisibility() {
    const selectedValue = this.kindSelectTarget.value

    if (selectedValue === "school_district") {
      this.schoolFieldsTarget.classList.remove("hidden")
    } else {
      this.schoolFieldsTarget.classList.add("hidden")
    }
  }
}
