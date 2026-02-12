import { Controller } from "@hotwired/stimulus"

// Creates Chart.js scatter charts directly (bypassing Chartkick) so that
// plugins (partisan zones, reference lines) and custom tooltips are part
// of the initial config — no polling or post-processing required.
//
// Chart.bundle.js is a UMD bundle loaded via importmap as a side effect
// in application.js (sets window.Chart). We reference the global here
// rather than using `import Chart from "Chart.bundle"` which fails
// because the UMD wrapper has no ES module default export.
export default class extends Controller {
  static values = {
    series:        Array,   // [{ name, data: [{x,y,name}], backgroundColor }]
    xLabel:        String,
    yLabel:        String,
    xFormat:       String,
    yFormat:       String,
    partisanZones: Boolean,
    referenceLine: Number,
    yMin:          Number,
    yMax:          Number,
    height:        { type: String, default: "500px" }
  }

  connect() {
    this.coordinateLookup = this.buildCoordinateLookup()
    this.createChart()
  }

  disconnect() {
    if (this.chart) {
      this.chart.destroy()
      this.chart = null
    }
  }

  createChart() {
    const canvas = document.createElement("canvas")
    this.element.style.height = this.heightValue
    this.element.style.position = "relative"
    this.element.appendChild(canvas)

    const datasets = this.seriesValue.map(series => ({
      label: series.name,
      data: series.data.map(pt => ({ x: pt.x, y: pt.y })),
      backgroundColor: series.backgroundColor || "#64748b",
      pointRadius: 5,
      pointHoverRadius: 7
    }))

    const plugins = []
    if (this.partisanZonesValue) {
      plugins.push(this.partisanZonePlugin())
    } else if (this.hasReferenceLineValue) {
      plugins.push(this.referenceLinePlugin())
    }

    const yScale = {
      title: { display: true, text: this.yLabelValue }
    }
    if (this.hasYMinValue) yScale.min = this.yMinValue
    if (this.hasYMaxValue) yScale.max = this.yMaxValue

    this.chart = new window.Chart(canvas, {
      type: "scatter",
      data: { datasets },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        onHover: (_event, elements) => {
          canvas.style.cursor = elements.length ? "pointer" : "default"
        },
        onClick: (_event, elements) => {
          if (!elements.length) return
          const el = elements[0]
          const { x, y } = this.chart.data.datasets[el.datasetIndex].data[el.index]
          const info = this.findInfo(x, y)
          if (info?.slug) {
            window.location.href = `/entities/${info.slug}`
          }
        },
        scales: {
          x: { title: { display: true, text: this.xLabelValue } },
          y: yScale
        },
        plugins: {
          legend: { display: false },
          tooltip: {
            callbacks: {
              title: (context) => {
                const { x, y } = context[0].parsed
                return this.findInfo(x, y)?.name || "Unknown"
              },
              label: (context) => {
                return [
                  `${this.xLabelValue}: ${this.formatValue(context.parsed.x, this.xFormatValue)}`,
                  `${this.yLabelValue}: ${this.formatValue(context.parsed.y, this.yFormatValue)}`
                ]
              }
            }
          }
        }
      },
      plugins
    })
  }

  // Chart.js plugin: draws partisan background zones + veto-proof lines + optional reference line
  partisanZonePlugin() {
    const zones = [
      { min: 0, max: 33.33, color: "rgba(37, 99, 235, 0.15)" },
      { min: 33.33, max: 45, color: "rgba(37, 99, 235, 0.08)" },
      { min: 45, max: 55, color: "rgba(139, 92, 246, 0.10)" },
      { min: 55, max: 66.67, color: "rgba(220, 38, 38, 0.08)" },
      { min: 66.67, max: 100, color: "rgba(220, 38, 38, 0.15)" }
    ]
    const vetoLines = [33.33, 66.67]
    const refLine = this.hasReferenceLineValue ? this.referenceLineValue : null

    return {
      id: "partisanZones",
      beforeDraw(chart) {
        const { ctx, chartArea, scales } = chart
        if (!chartArea || !scales.x) return

        const xScale = scales.x
        const yScale = scales.y
        const { top, bottom } = chartArea

        zones.forEach(zone => {
          const left = xScale.getPixelForValue(zone.min)
          const right = xScale.getPixelForValue(zone.max)
          ctx.fillStyle = zone.color
          ctx.fillRect(left, top, right - left, bottom - top)
        })

        ctx.save()
        ctx.setLineDash([6, 4])
        ctx.strokeStyle = "rgba(100, 100, 100, 0.5)"
        ctx.lineWidth = 1

        vetoLines.forEach(threshold => {
          const x = xScale.getPixelForValue(threshold)
          ctx.beginPath()
          ctx.moveTo(x, top)
          ctx.lineTo(x, bottom)
          ctx.stroke()
        })

        if (refLine !== null && yScale) {
          ctx.setLineDash([8, 4])
          ctx.strokeStyle = "rgba(34, 197, 94, 0.6)"
          ctx.lineWidth = 1.5
          const y = yScale.getPixelForValue(refLine)
          ctx.beginPath()
          ctx.moveTo(chartArea.left, y)
          ctx.lineTo(chartArea.right, y)
          ctx.stroke()
        }

        ctx.restore()
      }
    }
  }

  // Standalone reference line plugin (used when partisanZones is false)
  referenceLinePlugin() {
    const refLine = this.referenceLineValue

    return {
      id: "referenceLine",
      beforeDraw(chart) {
        const { ctx, chartArea, scales } = chart
        if (!chartArea || !scales.y) return

        ctx.save()
        ctx.setLineDash([8, 4])
        ctx.strokeStyle = "rgba(34, 197, 94, 0.6)"
        ctx.lineWidth = 1.5
        const y = scales.y.getPixelForValue(refLine)
        ctx.beginPath()
        ctx.moveTo(chartArea.left, y)
        ctx.lineTo(chartArea.right, y)
        ctx.stroke()
        ctx.restore()
      }
    }
  }

  buildCoordinateLookup() {
    const lookup = {}
    this.seriesValue.forEach(series => {
      series.data.forEach(pt => {
        const key = `${Math.round(pt.x * 100)}|${Math.round(pt.y * 100)}`
        lookup[key] = { name: pt.name, slug: pt.slug }
      })
    })
    return lookup
  }

  findInfo(x, y) {
    const key = `${Math.round(x * 100)}|${Math.round(y * 100)}`
    return this.coordinateLookup[key]
  }

  formatValue(value, format) {
    if (value == null) return "\u2014"
    switch (format) {
      case "currency": return "$" + Math.round(value).toLocaleString()
      case "percentage": return value.toFixed(1) + "%"
      case "integer": return Math.round(value).toLocaleString()
      default: return value.toLocaleString()
    }
  }
}
