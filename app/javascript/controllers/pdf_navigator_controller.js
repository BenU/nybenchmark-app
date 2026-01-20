import { Controller } from "@hotwired/stimulus"
import * as pdfjsLib from "pdfjs-dist"

// Configure PDF.js worker
pdfjsLib.GlobalWorkerOptions.workerSrc = "https://cdn.jsdelivr.net/npm/pdfjs-dist@4.8.69/build/pdf.worker.min.mjs"

export default class extends Controller {
  static targets = ["canvas", "pageInput", "pageDisplay", "totalPages", "zoomSelect", "container", "loading", "error"]
  static values = {
    url: String,
    initialPage: { type: Number, default: 1 }
  }

  connect() {
    this.pdfDoc = null
    this.currentPage = this.initialPageValue || 1
    this.zoom = "fit-width"
    this.rendering = false
    this.pendingPage = null

    this.loadPdf()
    this.setupResizeObserver()
    this.setupKeyboardNavigation()
  }

  disconnect() {
    if (this.resizeObserver) {
      this.resizeObserver.disconnect()
    }
    if (this.pdfDoc) {
      this.pdfDoc.destroy()
    }
    if (this.boundKeyHandler) {
      document.removeEventListener("keydown", this.boundKeyHandler)
    }
    clearTimeout(this.resizeTimeout)
  }

  async loadPdf() {
    if (!this.urlValue) {
      this.showError("No PDF URL provided")
      return
    }

    this.showLoading()

    try {
      const loadingTask = pdfjsLib.getDocument(this.urlValue)
      this.pdfDoc = await loadingTask.promise

      if (this.hasTotalPagesTarget) {
        this.totalPagesTarget.textContent = this.pdfDoc.numPages
      }

      // Clamp initial page to valid range
      this.currentPage = this.clampPage(this.currentPage)

      this.hideLoading()
      this.renderPage(this.currentPage)
    } catch (error) {
      console.error("Error loading PDF:", error)
      this.showError(`Failed to load PDF: ${error.message}`)
    }
  }

  async renderPage(pageNum) {
    if (!this.pdfDoc) return

    if (this.rendering) {
      this.pendingPage = pageNum
      return
    }

    this.rendering = true
    this.currentPage = pageNum
    this.updatePageDisplay()

    try {
      const page = await this.pdfDoc.getPage(pageNum)
      const canvas = this.canvasTarget
      const ctx = canvas.getContext("2d")

      // Calculate scale based on zoom setting
      const scale = this.calculateScale(page)
      const viewport = page.getViewport({ scale })

      // Set canvas dimensions
      canvas.height = viewport.height
      canvas.width = viewport.width

      const renderContext = {
        canvasContext: ctx,
        viewport: viewport
      }

      await page.render(renderContext).promise
    } catch (error) {
      console.error("Error rendering page:", error)
    } finally {
      this.rendering = false

      if (this.pendingPage !== null) {
        const nextPage = this.pendingPage
        this.pendingPage = null
        this.renderPage(nextPage)
      }
    }
  }

  calculateScale(page) {
    const defaultViewport = page.getViewport({ scale: 1 })
    const containerWidth = this.containerTarget.clientWidth - 20 // padding
    const containerHeight = this.containerTarget.clientHeight - 20

    switch (this.zoom) {
      case "fit-width":
        return containerWidth / defaultViewport.width
      case "fit-page":
        const scaleX = containerWidth / defaultViewport.width
        const scaleY = containerHeight / defaultViewport.height
        return Math.min(scaleX, scaleY)
      default:
        // Numeric zoom (0.5, 0.75, 1, 1.25, 1.5, 2)
        return parseFloat(this.zoom) || 1
    }
  }

  updatePageDisplay() {
    if (this.hasPageDisplayTarget) {
      this.pageDisplayTarget.textContent = this.currentPage
    }
    // Don't update pageInput automatically to avoid overwriting user edits
  }

  // Helper to clamp page number to valid range
  clampPage(pageNum) {
    if (!this.pdfDoc) return 1
    return Math.max(1, Math.min(pageNum, this.pdfDoc.numPages))
  }

  // Navigate to a specific page with bounds checking
  navigateTo(pageNum) {
    if (!this.pdfDoc) return
    this.renderPage(this.clampPage(pageNum))
  }

  // Navigation actions
  previousPage() {
    this.navigateTo(this.currentPage - 1)
  }

  nextPage() {
    this.navigateTo(this.currentPage + 1)
  }

  firstPage() {
    this.navigateTo(1)
  }

  lastPage() {
    if (this.pdfDoc) {
      this.navigateTo(this.pdfDoc.numPages)
    }
  }

  // Sync from form input to PDF
  goToPage() {
    if (!this.hasPageInputTarget || !this.pdfDoc) return

    const pageNum = parseInt(this.pageInputTarget.value, 10)
    if (isNaN(pageNum)) return

    this.navigateTo(pageNum)
  }

  // Capture current page to form
  captureCurrentPage() {
    if (this.hasPageInputTarget && this.pdfDoc) {
      this.pageInputTarget.value = this.currentPage
      // Trigger input event for any listeners
      this.pageInputTarget.dispatchEvent(new Event("input", { bubbles: true }))
    }
  }

  // Canvas click captures page
  canvasClicked() {
    this.captureCurrentPage()
  }

  // Zoom change
  zoomChanged() {
    if (!this.hasZoomSelectTarget) return

    this.zoom = this.zoomSelectTarget.value
    this.renderPage(this.currentPage)
  }

  // Responsive resize
  setupResizeObserver() {
    this.resizeObserver = new ResizeObserver(() => {
      if (this.zoom === "fit-width" || this.zoom === "fit-page") {
        // Debounce resize renders
        clearTimeout(this.resizeTimeout)
        this.resizeTimeout = setTimeout(() => {
          this.renderPage(this.currentPage)
        }, 150)
      }
    })

    if (this.hasContainerTarget) {
      this.resizeObserver.observe(this.containerTarget)
    }
  }

  // Keyboard navigation
  setupKeyboardNavigation() {
    this.boundKeyHandler = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this.boundKeyHandler)
  }

  isInputFocused(event) {
    const focusedTags = ["INPUT", "TEXTAREA", "SELECT"]
    return focusedTags.includes(event.target.tagName)
  }

  handleKeydown(event) {
    if (this.isInputFocused(event)) return

    switch (event.key) {
      case "ArrowLeft":
      case "PageUp":
        event.preventDefault()
        this.previousPage()
        break
      case "ArrowRight":
      case "PageDown":
        event.preventDefault()
        this.nextPage()
        break
      case "Home":
        event.preventDefault()
        this.firstPage()
        break
      case "End":
        event.preventDefault()
        this.lastPage()
        break
    }
  }

  // Loading/Error states
  showLoading() {
    if (this.hasLoadingTarget) {
      this.loadingTarget.classList.remove("hidden")
    }
    if (this.hasErrorTarget) {
      this.errorTarget.classList.add("hidden")
    }
  }

  hideLoading() {
    if (this.hasLoadingTarget) {
      this.loadingTarget.classList.add("hidden")
    }
  }

  showError(message) {
    this.hideLoading()
    if (this.hasErrorTarget) {
      this.errorTarget.textContent = message
      this.errorTarget.classList.remove("hidden")
    }
  }
}
