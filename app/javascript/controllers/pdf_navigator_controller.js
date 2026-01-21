import { Controller } from "@hotwired/stimulus"
import * as pdfjsLib from "pdfjs-dist"

// Configure PDF.js worker
pdfjsLib.GlobalWorkerOptions.workerSrc = "https://cdn.jsdelivr.net/npm/pdfjs-dist@4.8.69/build/pdf.worker.min.mjs"

export default class extends Controller {
  static targets = ["pagesContainer", "pageInput", "pageDisplay", "totalPages", "zoomSelect", "container", "loading", "error"]
  static values = {
    url: String,
    initialPage: { type: Number, default: 1 }
  }

  connect() {
    this.pdfDoc = null
    this.currentPage = this.initialPageValue || 1
    this.zoom = "fit-width"

    // Multi-page state
    this.pageElements = new Map()      // Map<pageNum, { wrapper, canvas, rendered }>
    this.pageViewports = []            // Cached viewports at scale=1
    this.visiblePages = new Set()      // Currently visible page numbers
    this.renderQueue = new Set()       // Pages queued for rendering
    this.activeRenders = new Map()     // In-flight render promises
    this.intersectionObserver = null   // For virtualization
    this.scrollSyncEnabled = true      // Prevent feedback loops
    this.scrollTimeout = null          // Debounce scroll sync
    this.mostVisiblePage = 1           // Current page based on visibility

    this.loadPdf()
    this.setupResizeObserver()
    this.setupKeyboardNavigation()
  }

  disconnect() {
    if (this.resizeObserver) {
      this.resizeObserver.disconnect()
    }
    if (this.intersectionObserver) {
      this.intersectionObserver.disconnect()
    }
    if (this.pdfDoc) {
      this.pdfDoc.destroy()
    }
    if (this.boundKeyHandler) {
      document.removeEventListener("keydown", this.boundKeyHandler)
    }
    clearTimeout(this.resizeTimeout)
    clearTimeout(this.scrollTimeout)
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

      // Setup all pages
      await this.setupPages()

      this.hideLoading()

      // Setup scroll observation and sync
      this.setupIntersectionObserver()
      this.setupScrollListener()

      // Scroll to initial page
      this.scrollToPage(this.currentPage, false)
    } catch (error) {
      console.error("Error loading PDF:", error)
      this.showError(`Failed to load PDF: ${error.message}`)
    }
  }

  async setupPages() {
    const numPages = this.pdfDoc.numPages

    // Fetch viewports for all pages (fast metadata)
    for (let i = 1; i <= numPages; i++) {
      const page = await this.pdfDoc.getPage(i)
      this.pageViewports[i] = page.getViewport({ scale: 1 })
    }

    // Create page wrappers
    for (let i = 1; i <= numPages; i++) {
      this.createPageWrapper(i)
    }

    // Initial render of visible pages
    this.renderVisiblePages()
  }

  createPageWrapper(pageNum) {
    const viewport = this.pageViewports[pageNum]
    const scale = this.calculateScale(viewport)
    const width = Math.floor(viewport.width * scale)
    const height = Math.floor(viewport.height * scale)

    // Create wrapper div
    const wrapper = document.createElement("div")
    wrapper.className = "pdf-page-wrapper relative bg-gray-200 shadow cursor-pointer"
    wrapper.dataset.page = pageNum
    wrapper.style.width = `${width}px`
    wrapper.style.height = `${height}px`

    // Create canvas (hidden until rendered)
    const canvas = document.createElement("canvas")
    canvas.className = "absolute inset-0"
    canvas.style.display = "none"
    wrapper.appendChild(canvas)

    // Click handler for capturing page
    wrapper.addEventListener("click", () => {
      this.capturePageNumber(pageNum)
    })

    this.pagesContainerTarget.appendChild(wrapper)

    this.pageElements.set(pageNum, {
      wrapper,
      canvas,
      rendered: false,
      currentScale: scale
    })
  }

  calculateScale(viewport) {
    const containerWidth = this.containerTarget.clientWidth - 40 // padding
    const containerHeight = this.containerTarget.clientHeight - 40

    switch (this.zoom) {
      case "fit-width":
        return containerWidth / viewport.width
      case "fit-page":
        const scaleX = containerWidth / viewport.width
        const scaleY = containerHeight / viewport.height
        return Math.min(scaleX, scaleY)
      default:
        // Numeric zoom (0.5, 0.75, 1, 1.25, 1.5, 2)
        return parseFloat(this.zoom) || 1
    }
  }

  setupIntersectionObserver() {
    this.intersectionObserver = new IntersectionObserver(
      this.handleIntersection.bind(this),
      {
        root: this.containerTarget,
        rootMargin: "200px 0px",  // Pre-render buffer
        threshold: [0, 0.1, 0.5, 0.9, 1.0]
      }
    )

    // Observe all page wrappers
    this.pageElements.forEach(({ wrapper }) => {
      this.intersectionObserver.observe(wrapper)
    })
  }

  handleIntersection(entries) {
    entries.forEach(entry => {
      const pageNum = parseInt(entry.target.dataset.page, 10)

      if (entry.isIntersecting) {
        this.visiblePages.add(pageNum)
        this.queueRender(pageNum)
      } else {
        this.visiblePages.delete(pageNum)
      }
    })

    // Process render queue
    this.processRenderQueue()
  }

  queueRender(pageNum) {
    const pageEl = this.pageElements.get(pageNum)
    if (pageEl && !pageEl.rendered && !this.activeRenders.has(pageNum)) {
      this.renderQueue.add(pageNum)
    }
  }

  async processRenderQueue() {
    // Limit concurrent renders
    const maxConcurrent = 3

    if (this.activeRenders.size >= maxConcurrent || this.renderQueue.size === 0) {
      return
    }

    // Get next page to render (prioritize visible pages)
    const visibleQueued = [...this.renderQueue].filter(p => this.visiblePages.has(p))
    const nextPage = visibleQueued.length > 0 ? visibleQueued[0] : [...this.renderQueue][0]

    if (nextPage) {
      this.renderQueue.delete(nextPage)
      await this.renderPage(nextPage)
      this.processRenderQueue()
    }
  }

  async renderPage(pageNum) {
    const pageEl = this.pageElements.get(pageNum)
    if (!pageEl || this.activeRenders.has(pageNum)) return

    const { wrapper, canvas } = pageEl

    try {
      const page = await this.pdfDoc.getPage(pageNum)
      const baseViewport = page.getViewport({ scale: 1 })
      const scale = this.calculateScale(baseViewport)
      const scaledViewport = page.getViewport({ scale })

      // Update wrapper dimensions for current scale
      wrapper.style.width = `${Math.floor(scaledViewport.width)}px`
      wrapper.style.height = `${Math.floor(scaledViewport.height)}px`

      // Setup canvas
      canvas.width = Math.floor(scaledViewport.width)
      canvas.height = Math.floor(scaledViewport.height)
      const ctx = canvas.getContext("2d")

      const renderTask = page.render({
        canvasContext: ctx,
        viewport: scaledViewport
      })

      this.activeRenders.set(pageNum, renderTask)

      await renderTask.promise

      // Show canvas now that it's rendered
      canvas.style.display = "block"
      pageEl.rendered = true
      pageEl.currentScale = scale
    } catch (error) {
      if (error.name !== "RenderingCancelledException") {
        console.error(`Error rendering page ${pageNum}:`, error)
      }
    } finally {
      this.activeRenders.delete(pageNum)
    }
  }

  renderVisiblePages() {
    this.pageElements.forEach((_, pageNum) => {
      // Queue first few pages immediately
      if (pageNum <= 3) {
        this.queueRender(pageNum)
      }
    })
    this.processRenderQueue()
  }

  setupScrollListener() {
    this.containerTarget.addEventListener("scroll", () => {
      if (!this.scrollSyncEnabled) return

      clearTimeout(this.scrollTimeout)
      this.scrollTimeout = setTimeout(() => {
        this.updateCurrentPageFromScroll()
      }, 50)
    })
  }

  updateCurrentPageFromScroll() {
    const containerRect = this.containerTarget.getBoundingClientRect()
    const containerMidY = containerRect.top + containerRect.height / 2

    let closestPage = 1
    let closestDistance = Infinity

    this.pageElements.forEach(({ wrapper }, pageNum) => {
      const rect = wrapper.getBoundingClientRect()
      const pageMidY = rect.top + rect.height / 2
      const distance = Math.abs(pageMidY - containerMidY)

      if (distance < closestDistance) {
        closestDistance = distance
        closestPage = pageNum
      }
    })

    if (closestPage !== this.currentPage) {
      this.currentPage = closestPage
      this.updatePageDisplay()
    }
  }

  updatePageDisplay() {
    if (this.hasPageDisplayTarget) {
      this.pageDisplayTarget.textContent = this.currentPage
    }
  }

  // Helper to clamp page number to valid range
  clampPage(pageNum) {
    if (!this.pdfDoc) return 1
    return Math.max(1, Math.min(pageNum, this.pdfDoc.numPages))
  }

  scrollToPage(pageNum, smooth = true) {
    const clamped = this.clampPage(pageNum)
    const pageEl = this.pageElements.get(clamped)

    if (!pageEl) return

    // Temporarily disable scroll sync to prevent feedback
    this.scrollSyncEnabled = false

    pageEl.wrapper.scrollIntoView({
      behavior: smooth ? "smooth" : "instant",
      block: "start"
    })

    this.currentPage = clamped
    this.updatePageDisplay()

    // Re-enable scroll sync after animation
    setTimeout(() => {
      this.scrollSyncEnabled = true
    }, smooth ? 500 : 100)
  }

  // Navigation actions
  previousPage() {
    this.scrollToPage(this.currentPage - 1)
  }

  nextPage() {
    this.scrollToPage(this.currentPage + 1)
  }

  firstPage() {
    this.scrollToPage(1)
  }

  lastPage() {
    if (this.pdfDoc) {
      this.scrollToPage(this.pdfDoc.numPages)
    }
  }

  // Sync from form input to PDF
  goToPage() {
    if (!this.hasPageInputTarget || !this.pdfDoc) return

    const pageNum = parseInt(this.pageInputTarget.value, 10)
    if (isNaN(pageNum)) return

    this.scrollToPage(pageNum)
  }

  // Capture specific page to form
  capturePageNumber(pageNum) {
    if (this.hasPageInputTarget) {
      this.pageInputTarget.value = pageNum
      this.pageInputTarget.dispatchEvent(new Event("input", { bubbles: true }))
    }
  }

  // Capture current page to form
  captureCurrentPage() {
    this.capturePageNumber(this.currentPage)
  }

  // Zoom change - re-render all pages
  zoomChanged() {
    if (!this.hasZoomSelectTarget) return

    this.zoom = this.zoomSelectTarget.value

    // Mark all pages as unrendered
    this.pageElements.forEach((pageEl) => {
      pageEl.rendered = false
      pageEl.canvas.style.display = "none"
    })

    // Update all wrapper dimensions
    this.pageElements.forEach((pageEl, pageNum) => {
      const viewport = this.pageViewports[pageNum]
      const scale = this.calculateScale(viewport)
      pageEl.wrapper.style.width = `${Math.floor(viewport.width * scale)}px`
      pageEl.wrapper.style.height = `${Math.floor(viewport.height * scale)}px`
    })

    // Re-render visible pages
    this.visiblePages.forEach(pageNum => {
      this.queueRender(pageNum)
    })
    this.processRenderQueue()
  }

  // Responsive resize
  setupResizeObserver() {
    this.resizeObserver = new ResizeObserver(() => {
      if (this.zoom === "fit-width" || this.zoom === "fit-page") {
        // Debounce resize renders
        clearTimeout(this.resizeTimeout)
        this.resizeTimeout = setTimeout(() => {
          if (this.pdfDoc) {
            this.zoomChanged()
          }
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
