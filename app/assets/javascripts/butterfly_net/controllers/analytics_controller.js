import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    summaryUrl: String,
    topErrorsUrl: String,
    timeSeriesUrl: String
  }

  connect() {
    this.fetchAndRender()
  }

  async fetchAndRender() {
    try {
      const [summary, topErrors, timeSeries] = await Promise.all([
        fetch(this.summaryUrlValue).then(r => r.json()),
        fetch(this.topErrorsUrlValue).then(r => r.json()),
        fetch(this.timeSeriesUrlValue).then(r => r.json())
      ])

      this.#renderSummaryCards(summary)
      this.#renderStatusChart(summary.status_breakdown)
      this.#renderTopErrorsChart(topErrors.top_errors)
      this.#renderUsersChart(timeSeries.affected_users)
      this.#renderOccurrencesChart(timeSeries.occurrences)
      this.#renderNewErrorsChart(timeSeries.new_errors)
    } catch (error) {
      console.error("Failed to fetch analytics data:", error)
      this.#showError("Failed to load analytics data. Please refresh the page.")
    }
  }

  #renderSummaryCards(data) {
    document.getElementById("kpi-open-errors").textContent = data.total_open_errors
    document.getElementById("kpi-affected-users").textContent = data.total_affected_users_today
    document.getElementById("kpi-occurrences").textContent = data.total_occurrences_today

    const mttr = data.mean_time_to_resolution
    document.getElementById("kpi-mttr").textContent = mttr === 0 ? "N/A" : mttr.toFixed(1) + " hrs"
  }

  #renderStatusChart(statusData) {
    const statusColors = { open: "#DC2626", in_progress: "#D97706", resolved: "#059669", dismissed: "#6B7280" }
    const statusLabels = { open: "Open", in_progress: "In Progress", resolved: "Resolved", dismissed: "Dismissed" }

    new ApexCharts(document.querySelector("#status-chart"), {
      series: Object.values(statusData),
      chart: { type: "donut", height: 300 },
      labels: Object.keys(statusData).map(k => statusLabels[k] || k),
      colors: Object.keys(statusData).map(k => statusColors[k] || "#6B7280"),
      legend: { position: "bottom" },
      dataLabels: {
        enabled: true,
        formatter: (val, opts) => opts.w.config.series[opts.seriesIndex]
      },
      plotOptions: {
        pie: {
          donut: {
            labels: {
              show: true,
              total: {
                show: true,
                label: "Total Errors",
                formatter: w => w.globals.seriesTotals.reduce((a, b) => a + b, 0)
              }
            }
          }
        }
      }
    }).render()
  }

  #renderTopErrorsChart(topErrors) {
    if (!topErrors || topErrors.length === 0) {
      document.getElementById("top-errors-chart").innerHTML = '<p class="text-center text-gray-500">No data available</p>'
      return
    }

    new ApexCharts(document.querySelector("#top-errors-chart"), {
      series: [{ name: "Occurrences", data: topErrors.map(e => e.occurrence_count) }],
      chart: { type: "bar", height: 300 },
      plotOptions: { bar: { horizontal: true, dataLabels: { position: "top" } } },
      dataLabels: { enabled: true, offsetX: 30, style: { fontSize: "12px" } },
      xaxis: {
        categories: topErrors.map(e => this.#truncate(e.exception_class, 25)),
        title: { text: "Occurrences" }
      },
      yaxis: { labels: { style: { fontSize: "11px" } } },
      colors: ["#3B82F6"],
      tooltip: {
        custom: ({ dataPointIndex }) => {
          const e = topErrors[dataPointIndex]
          return `<div class="px-3 py-2"><div class="font-semibold">${e.exception_class}</div>` +
            `<div class="text-sm text-gray-600">${this.#truncate(e.message, 50)}</div>` +
            `<div class="text-sm mt-1">Occurrences: ${e.occurrence_count}</div></div>`
        }
      }
    }).render()
  }

  #renderUsersChart(data) {
    if (!data || data.length === 0) {
      document.getElementById("users-chart").innerHTML = '<p class="text-center text-gray-500">No data available</p>'
      return
    }

    new ApexCharts(document.querySelector("#users-chart"), {
      series: [{ name: "Affected Users", data: data.map(d => d.count) }],
      chart: { type: "area", height: 300, zoom: { enabled: false } },
      dataLabels: { enabled: false },
      stroke: { curve: "smooth", width: 2 },
      fill: { type: "gradient", gradient: { opacityFrom: 0.6, opacityTo: 0.1 } },
      xaxis: {
        categories: data.map(d => this.#formatDate(d.date)),
        labels: { rotate: -45, rotateAlways: false, style: { fontSize: "11px" } }
      },
      yaxis: { title: { text: "Users" } },
      colors: ["#8B5CF6"]
    }).render()
  }

  #renderOccurrencesChart(data) {
    if (!data || data.length === 0) {
      document.getElementById("occurrences-chart").innerHTML = '<p class="text-center text-gray-500">No data available</p>'
      return
    }

    new ApexCharts(document.querySelector("#occurrences-chart"), {
      series: [{ name: "Occurrences", data: data.map(d => d.count) }],
      chart: { type: "line", height: 300, zoom: { enabled: false } },
      dataLabels: { enabled: false },
      stroke: { curve: "smooth", width: 3 },
      xaxis: {
        categories: data.map(d => this.#formatDate(d.date)),
        labels: { rotate: -45, rotateAlways: false, style: { fontSize: "11px" } }
      },
      yaxis: { title: { text: "Occurrences" } },
      colors: ["#EF4444"]
    }).render()
  }

  #renderNewErrorsChart(data) {
    if (!data || data.length === 0) {
      document.getElementById("new-errors-chart").innerHTML = '<p class="text-center text-gray-500">No data available</p>'
      return
    }

    new ApexCharts(document.querySelector("#new-errors-chart"), {
      series: [{ name: "New Errors", data: data.map(d => d.count) }],
      chart: { type: "bar", height: 300, zoom: { enabled: false } },
      plotOptions: { bar: { columnWidth: "70%" } },
      dataLabels: { enabled: false },
      xaxis: {
        categories: data.map(d => this.#formatDate(d.date)),
        labels: { rotate: -45, rotateAlways: false, style: { fontSize: "11px" } }
      },
      yaxis: { title: { text: "New Errors" } },
      colors: ["#F59E0B"]
    }).render()
  }

  #formatDate(dateStr) {
    const d = new Date(dateStr)
    return (d.getMonth() + 1) + "/" + d.getDate()
  }

  #truncate(text, maxLength) {
    if (!text) return ""
    return text.length <= maxLength ? text : text.substring(0, maxLength) + "..."
  }

  #showError(message) {
    ["kpi-cards", "status-chart", "top-errors-chart", "users-chart"].forEach(id => {
      const el = document.getElementById(id)
      if (el) el.innerHTML = `<div class="text-red-600 text-center py-4">${message}</div>`
    })
  }
}
