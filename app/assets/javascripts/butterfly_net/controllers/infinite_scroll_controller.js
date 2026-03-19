import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sentinel", "loadingIndicator"]
  static values = { url: String }

  connect() {
    this.currentPage = 1
    this.isLoading = false
    this.hasMore = true

    if (!this.hasSentinelTarget) return

    this.observer = new IntersectionObserver(
      (entries) => this.handleIntersection(entries),
      { rootMargin: "200px" }
    )
    this.observer.observe(this.sentinelTarget)
  }

  disconnect() {
    this.observer?.disconnect()
  }

  handleIntersection(entries) {
    entries.forEach(entry => {
      if (entry.isIntersecting && !this.isLoading && this.hasMore) {
        this.loadMore()
      }
    })
  }

  async loadMore() {
    this.isLoading = true
    this.showLoading()

    const nextPage = this.currentPage + 1
    const url = `${this.urlValue}?page=${nextPage}`

    try {
      const response = await fetch(url, {
        headers: {
          "Accept": "application/json",
          "X-Requested-With": "XMLHttpRequest"
        }
      })

      if (!response.ok) throw new Error("Network response was not ok")

      const data = await response.json()

      if (data.error_logs && data.error_logs.length > 0) {
        this.appendRows(data.error_logs)
        this.currentPage = nextPage
        this.hasMore = !!data.pagy.next
        if (!this.hasMore) this.observer.disconnect()
      } else {
        this.hasMore = false
        this.observer.disconnect()
      }
    } catch (error) {
      console.error("Error loading more items:", error)
    } finally {
      this.hideLoading()
      this.isLoading = false
    }
  }

  get tableBody() {
    return this.element.querySelector("tbody")
  }

  appendRows(errorLogs) {
    errorLogs.forEach(errorLog => {
      this.tableBody.appendChild(this.createRow(errorLog))
    })
  }

  createRow(errorLog) {
    const row = document.createElement("tr")
    row.appendChild(this.#cell("whitespace-nowrap py-4 pl-4 pr-3 text-sm sm:pl-6", this.#statusBadge(errorLog.status), true))
    row.appendChild(this.#cell("whitespace-nowrap px-3 py-4 text-sm font-medium text-gray-900", errorLog.exception_class))
    row.appendChild(this.#cell("px-3 py-4 text-sm text-gray-500", this.#truncate(errorLog.message, 60)))
    row.appendChild(this.#cell("whitespace-nowrap px-3 py-4 text-sm text-gray-900", `<span class="font-medium">${errorLog.occurrence_count}</span>`, true))
    row.appendChild(this.#cell(
      "whitespace-nowrap px-3 py-4 text-sm text-gray-900",
      errorLog.affected_count > 0
        ? `<span class="font-medium">${errorLog.affected_count}</span>`
        : '<span class="text-gray-400">—</span>',
      true
    ))
    row.appendChild(this.#cell("whitespace-nowrap px-3 py-4 text-sm text-gray-500", this.#timeAgo(errorLog.last_seen)))
    row.appendChild(this.#cell("whitespace-nowrap px-3 py-4 text-sm", this.#githubIssueHtml(errorLog), true))
    row.appendChild(this.#cell(
      "relative whitespace-nowrap py-4 pl-3 pr-4 text-right text-sm font-medium sm:pr-6",
      `<a href="${this.urlValue}/${errorLog.id}" class="text-blue-600 hover:text-blue-900">View</a>`,
      true
    ))
    return row
  }

  showLoading() {
    if (this.hasLoadingIndicatorTarget) {
      this.loadingIndicatorTarget.classList.remove("hidden")
    }
  }

  hideLoading() {
    if (this.hasLoadingIndicatorTarget) {
      this.loadingIndicatorTarget.classList.add("hidden")
    }
  }

  #cell(className, content, isHtml = false) {
    const td = document.createElement("td")
    td.className = className
    if (isHtml) {
      td.innerHTML = content
    } else {
      td.textContent = content
    }
    return td
  }

  #statusBadge(status) {
    const badges = {
      open: '<span class="inline-flex items-center rounded-md bg-red-50 px-2 py-1 text-xs font-medium text-red-700 ring-1 ring-inset ring-red-600/10">Open</span>',
      in_progress: '<span class="inline-flex items-center rounded-md bg-yellow-50 px-2 py-1 text-xs font-medium text-yellow-800 ring-1 ring-inset ring-yellow-600/20">In Progress</span>',
      resolved: '<span class="inline-flex items-center rounded-md bg-green-50 px-2 py-1 text-xs font-medium text-green-700 ring-1 ring-inset ring-green-600/20">Resolved</span>',
      dismissed: '<span class="inline-flex items-center rounded-md bg-gray-50 px-2 py-1 text-xs font-medium text-gray-600 ring-1 ring-inset ring-gray-500/10">Dismissed</span>'
    }
    return badges[status] || badges.open
  }

  #githubIssueHtml(errorLog) {
    if (errorLog.has_github_issue) {
      return `<a href="${errorLog.github_issue_url}" target="_blank" rel="noopener noreferrer" class="inline-flex items-center gap-1 text-gray-900 hover:text-gray-700">
        <svg class="h-5 w-5" fill="currentColor" viewBox="0 0 16 16">
          <path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0016 8c0-4.42-3.58-8-8-8z"/>
        </svg>
        <span class="font-medium">#${errorLog.github_issue_number}</span>
      </a>`
    }
    return '<span class="text-gray-400">—</span>'
  }

  #truncate(text, length) {
    if (!text || text.length <= length) return text || ""
    return text.substring(0, length - 3) + "..."
  }

  #timeAgo(dateString) {
    const date = new Date(dateString)
    const now = new Date()
    const seconds = Math.floor((now - date) / 1000)
    const intervals = {
      year: 31536000,
      month: 2592000,
      week: 604800,
      day: 86400,
      hour: 3600,
      minute: 60
    }
    for (const [unit, secs] of Object.entries(intervals)) {
      const count = Math.floor(seconds / secs)
      if (count >= 1) return `${count} ${unit}${count === 1 ? "" : "s"} ago`
    }
    return "just now"
  }
}
