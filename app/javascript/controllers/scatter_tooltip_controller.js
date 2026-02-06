import { Controller } from "@hotwired/stimulus"

// Enhances Chartkick scatter charts with district names in tooltips.
// Uses coordinate matching to find district names since Chart.js may reorder points.
export default class extends Controller {
  static values = {
    points: Array,
    xFormat: String,
    yFormat: String,
    xLabel: String,
    yLabel: String
  }

  connect() {
    // Wait for Chartkick to render the chart
    requestAnimationFrame(() => {
      this.configureTooltip()
    })
  }

  configureTooltip() {
    const chartElement = this.element.querySelector("canvas")
    if (!chartElement) return

    // Get the Chart.js instance from Chartkick's registry
    const chartId = chartElement.id || "scatter-chart"
    const chart = Chartkick.charts[chartId]?.chart
    if (!chart) return

    // Build a lookup map using coordinates as keys
    this.nameLookup = this.buildCoordinateLookup()

    // Configure custom tooltip
    const self = this
    chart.options.plugins.tooltip = {
      ...chart.options.plugins.tooltip,
      callbacks: {
        title: function(context) {
          // Look up district name by coordinates
          const x = context[0].parsed.x
          const y = context[0].parsed.y
          return self.findNameByCoordinates(x, y) || "Unknown District"
        },
        label: function(context) {
          const xVal = self.formatValue(context.parsed.x, self.xFormatValue)
          const yVal = self.formatValue(context.parsed.y, self.yFormatValue)
          return [
            `${self.xLabelValue}: ${xVal}`,
            `${self.yLabelValue}: ${yVal}`
          ]
        }
      }
    }

    chart.update()
  }

  // Build lookup keyed by "x|y" coordinate string
  buildCoordinateLookup() {
    const lookup = {}
    this.pointsValue.forEach((series) => {
      series.data.forEach((point) => {
        // Use rounded coordinates as key to handle floating point precision
        const key = `${Math.round(point.x * 100)}|${Math.round(point.y * 100)}`
        lookup[key] = point.name
      })
    })
    return lookup
  }

  findNameByCoordinates(x, y) {
    const key = `${Math.round(x * 100)}|${Math.round(y * 100)}`
    return this.nameLookup[key]
  }

  formatValue(value, format) {
    if (value == null) return "—"

    switch (format) {
      case "currency":
        return "$" + Math.round(value).toLocaleString()
      case "percentage":
        return value.toFixed(1) + "%"
      case "integer":
        return Math.round(value).toLocaleString()
      default:
        return value.toLocaleString()
    }
  }
}
