import { Controller } from "@hotwired/stimulus"

// Toggles between "Top 10" and "Bottom 10" ranking tables.
// Each ranking card has two <tbody> elements (top/bottom) and two toggle buttons.
export default class extends Controller {
  static targets = ["topBody", "bottomBody", "topButton", "bottomButton"]

  connect() {
    this.showTop()
  }

  showTop() {
    this.topBodyTarget.classList.remove("hidden")
    this.bottomBodyTarget.classList.add("hidden")
    this.topButtonTarget.classList.add("ranking-toggle--active")
    this.bottomButtonTarget.classList.remove("ranking-toggle--active")
  }

  showBottom() {
    this.topBodyTarget.classList.add("hidden")
    this.bottomBodyTarget.classList.remove("hidden")
    this.topButtonTarget.classList.remove("ranking-toggle--active")
    this.bottomButtonTarget.classList.add("ranking-toggle--active")
  }
}
