import { Controller } from "@hotwired/stimulus"

// Provides year navigation for county comparison charts.
// Supports: arrow buttons, range slider, and mouse wheel scrolling.
// Preserves scroll position when navigating between years.
export default class extends Controller {
  static values = {
    years: Array,
    current: Number,
    url: String
  }

  static targets = ["display", "slider", "prevBtn", "nextBtn"]

  connect() {
    this.index = this.yearsValue.indexOf(this.currentValue)
    if (this.index < 0) this.index = this.yearsValue.length - 1
    this.updateButtons()

    this.boundWheel = this.handleWheel.bind(this)
    this.element.addEventListener("wheel", this.boundWheel, { passive: false })

    // Restore scroll position immediately — by the time connect() runs,
    // turbo:render has already fired so we can't listen for it.
    this.restoreScroll()
  }

  disconnect() {
    this.element.removeEventListener("wheel", this.boundWheel)
  }

  previous() {
    if (this.index > 0) {
      this.index--
      this.navigate()
    }
  }

  next() {
    if (this.index < this.yearsValue.length - 1) {
      this.index++
      this.navigate()
    }
  }

  slide() {
    this.index = parseInt(this.sliderTarget.value)
    this.navigate()
  }

  handleWheel(event) {
    event.preventDefault()
    if (this.scrollTimeout) return

    if (event.deltaY < 0 && this.index < this.yearsValue.length - 1) {
      this.index++
      this.navigate()
    } else if (event.deltaY > 0 && this.index > 0) {
      this.index--
      this.navigate()
    }

    this.scrollTimeout = setTimeout(() => { this.scrollTimeout = null }, 300)
  }

  navigate() {
    const year = this.yearsValue[this.index]
    this.displayTarget.textContent = year
    this.sliderTarget.value = this.index
    this.updateButtons()

    // Save scroll position before Turbo navigates
    sessionStorage.setItem("county-compare-scroll", window.scrollY.toString())

    const url = `${this.urlValue}?year=${year}`
    Turbo.visit(url, { action: "replace" })
  }

  restoreScroll() {
    const saved = sessionStorage.getItem("county-compare-scroll")
    if (saved) {
      requestAnimationFrame(() => {
        window.scrollTo(0, parseInt(saved))
        sessionStorage.removeItem("county-compare-scroll")
      })
    }
  }

  updateButtons() {
    this.prevBtnTarget.disabled = this.index <= 0
    this.nextBtnTarget.disabled = this.index >= this.yearsValue.length - 1
  }
}
