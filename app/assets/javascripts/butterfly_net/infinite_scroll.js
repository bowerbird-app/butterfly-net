// Infinite scroll implementation for error logs
(function () {
  'use strict';

  class InfiniteScroll {
    constructor(container, options = {}) {
      this.container = container;
      this.tableBody = container.querySelector('tbody');
      this.loadingIndicator = container.querySelector('#loading-indicator');
      this.sentinel = container.querySelector('#scroll-sentinel');
      this.currentPage = parseInt(container.dataset.currentPage || '1', 10);
      this.isLoading = false;
      this.hasMore = container.dataset.hasMore === 'true';
      this.baseUrl = options.baseUrl || container.dataset.baseUrl || window.location.pathname;
      this.viewMode = container.dataset.viewMode || 'index';

      this.init();
    }

    init() {
      if (!this.sentinel || !this.hasMore) return;

      // Use IntersectionObserver to detect when user scrolls near the bottom
      this.observer = new IntersectionObserver(
        (entries) => this.handleIntersection(entries),
        { rootMargin: '200px' }
      );

      this.observer.observe(this.sentinel);
    }

    handleIntersection(entries) {
      entries.forEach(entry => {
        if (entry.isIntersecting && !this.isLoading && this.hasMore) {
          this.loadMore();
        }
      });
    }

    async loadMore() {
      this.isLoading = true;
      this.showLoading();

      const nextPage = this.currentPage + 1;
      const separator = this.baseUrl.includes('?') ? '&' : '?';
      const url = `${this.baseUrl}${separator}page=${nextPage}`;

      try {
        const response = await fetch(url, {
          headers: {
            'Accept': 'application/json',
            'X-Requested-With': 'XMLHttpRequest'
          }
        });

        if (!response.ok) throw new Error('Network response was not ok');

        const data = await response.json();

        if (data.error_logs && data.error_logs.length > 0) {
          this.appendRows(data.error_logs);
          this.currentPage = nextPage;

          // Check if there are more pages
          this.hasMore = !!data.pagy.next;
          if (!this.hasMore) {
            this.observer.disconnect();
          }
        } else {
          this.hasMore = false;
          this.observer.disconnect();
        }
      } catch (error) {
        console.error('Error loading more items:', error);
      } finally {
        this.hideLoading();
        this.isLoading = false;
      }
    }

    appendRows(errorLogs) {
      errorLogs.forEach(errorLog => {
        const row = this.createRow(errorLog);
        this.tableBody.appendChild(row);
      });
    }

    createRow(errorLog) {
      const row = document.createElement('tr');
      row.className = 'hover:bg-[var(--table-row-hover-background-color)] transition-colors duration-fast';

      if (this.viewMode === 'grouped') {
        return this.createGroupedRow(row, errorLog);
      }

      return this.createIndexRow(row, errorLog);
    }

    createIndexRow(row, errorLog) {
      // Exception class
      const exceptionCell = document.createElement('td');
      exceptionCell.className = 'px-[var(--table-padding)] py-[var(--table-padding)] text-sm text-[var(--table-cell-text-color)]';
      exceptionCell.textContent = errorLog.exception_class;

      // Occurrences
      const occurrencesCell = document.createElement('td');
      occurrencesCell.className = 'px-[var(--table-padding)] py-[var(--table-padding)] text-sm text-[var(--table-cell-text-color)]';
      occurrencesCell.innerHTML = `<span class="font-medium">${errorLog.occurrence_count}</span>`;

      // Users Affected
      const usersCell = document.createElement('td');
      usersCell.className = 'px-[var(--table-padding)] py-[var(--table-padding)] text-sm text-[var(--table-cell-text-color)]';
      usersCell.innerHTML = errorLog.affected_count > 0
        ? `<span class="font-medium">${errorLog.affected_count}</span>`
        : '<span class="text-gray-400">—</span>';

      // Last Seen
      const lastSeenCell = document.createElement('td');
      lastSeenCell.className = 'px-[var(--table-padding)] py-[var(--table-padding)] text-sm text-[var(--table-cell-text-color)]';
      lastSeenCell.textContent = this.timeAgo(errorLog.last_seen);

      // View link
      const viewCell = document.createElement('td');
      viewCell.className = 'px-[var(--table-padding)] py-[var(--table-padding)] text-sm text-[var(--table-cell-text-color)]';
      const dashboardPath = errorLog.dashboard_path || `${this.baseUrl.replace(/\/$/, '')}/dashboard/${errorLog.id}`;
      viewCell.innerHTML = this.getViewLinkHtml(dashboardPath);

      row.appendChild(exceptionCell);
      row.appendChild(occurrencesCell);
      row.appendChild(usersCell);
      row.appendChild(lastSeenCell);
      row.appendChild(viewCell);

      return row;
    }

    createGroupedRow(row, errorLog) {
      // Status badge
      const statusCell = document.createElement('td');
      statusCell.className = 'px-[var(--table-padding)] py-[var(--table-padding)] text-sm text-[var(--table-cell-text-color)]';
      statusCell.innerHTML = errorLog.status ? this.getStatusBadge(errorLog.status) : '';

      // Exception class
      const exceptionCell = document.createElement('td');
      exceptionCell.className = 'px-[var(--table-padding)] py-[var(--table-padding)] text-sm text-[var(--table-cell-text-color)]';
      exceptionCell.textContent = errorLog.exception_class;

      // Message
      const messageCell = document.createElement('td');
      messageCell.className = 'px-[var(--table-padding)] py-[var(--table-padding)] text-sm text-[var(--table-cell-text-color)]';
      messageCell.textContent = errorLog.message ? this.truncate(errorLog.message, 60) : '';

      // Occurrences
      const occurrencesCell = document.createElement('td');
      occurrencesCell.className = 'px-[var(--table-padding)] py-[var(--table-padding)] text-sm text-[var(--table-cell-text-color)]';
      occurrencesCell.innerHTML = `<span class="font-medium">${errorLog.occurrence_count}</span>`;

      // Users Affected
      const usersCell = document.createElement('td');
      usersCell.className = 'px-[var(--table-padding)] py-[var(--table-padding)] text-sm text-[var(--table-cell-text-color)]';
      usersCell.innerHTML = errorLog.affected_count > 0
        ? `<span class="font-medium">${errorLog.affected_count}</span>`
        : '<span class="text-gray-400">—</span>';

      // Last Seen
      const lastSeenCell = document.createElement('td');
      lastSeenCell.className = 'px-[var(--table-padding)] py-[var(--table-padding)] text-sm text-[var(--table-cell-text-color)]';
      lastSeenCell.textContent = this.timeAgo(errorLog.last_seen);

      // GitHub Issue
      const githubCell = document.createElement('td');
      githubCell.className = 'px-[var(--table-padding)] py-[var(--table-padding)] text-sm text-[var(--table-cell-text-color)]';
      githubCell.innerHTML = this.getGithubIssueHtml(errorLog);

      // View link
      const viewCell = document.createElement('td');
      viewCell.className = 'px-[var(--table-padding)] py-[var(--table-padding)] text-sm text-[var(--table-cell-text-color)]';
      const dashboardPath = errorLog.dashboard_path || `${this.baseUrl.replace(/\/$/, '')}/dashboard/${errorLog.id}`;
      viewCell.innerHTML = this.getViewLinkHtml(dashboardPath);

      row.appendChild(statusCell);
      row.appendChild(exceptionCell);
      row.appendChild(messageCell);
      row.appendChild(occurrencesCell);
      row.appendChild(usersCell);
      row.appendChild(lastSeenCell);
      row.appendChild(githubCell);
      row.appendChild(viewCell);

      return row;
    }

    getViewLinkHtml(dashboardPath) {
      return `<a href="${dashboardPath}" class="inline-flex items-center justify-center gap-2 rounded-[var(--button-border-radius)] font-medium cursor-pointer transition-colors duration-base focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--button-focus-ring-color)] focus-visible:ring-offset-2 focus-visible:ring-offset-[var(--button-focus-ring-offset-color)] disabled:pointer-events-none disabled:opacity-[var(--button-disabled-opacity)] px-[var(--button-padding-x-sm)] py-[var(--button-padding-y-sm)] text-xs bg-[var(--button-ghost-background-color)] hover:bg-[var(--button-ghost-hover-background-color)] text-[var(--button-ghost-text-color)] border border-[var(--button-ghost-border-color)]">View</a>`;
    }

    getStatusBadge(status) {
      const badges = {
        'open': '<span class="inline-flex items-center gap-1 rounded-full font-medium transition-colors duration-base border whitespace-nowrap bg-[var(--badge-primary-background-color)] text-[var(--badge-primary-text-color)] border-[var(--badge-primary-border-color)] text-sm px-3 py-1">Open</span>',
        'in_progress': '<span class="inline-flex items-center gap-1 rounded-full font-medium transition-colors duration-base border whitespace-nowrap bg-[var(--badge-warning-background-color)] text-[var(--badge-warning-text-color)] border-[var(--badge-warning-border-color)] text-sm px-3 py-1">In Progress</span>',
        'resolved': '<span class="inline-flex items-center gap-1 rounded-full font-medium transition-colors duration-base border whitespace-nowrap bg-[var(--badge-success-background-color)] text-[var(--badge-success-text-color)] border-[var(--badge-success-border-color)] text-sm px-3 py-1">Resolved</span>',
        'dismissed': '<span class="inline-flex items-center gap-1 rounded-full font-medium transition-colors duration-base border whitespace-nowrap bg-[var(--badge-default-background-color)] text-[var(--badge-default-text-color)] border-[var(--badge-default-border-color)] text-sm px-3 py-1">Dismissed</span>'
      };
      return badges[status] || badges['open'];
    }

    getGithubIssueHtml(errorLog) {
      if (errorLog.has_github_issue) {
        return `
          <a href="${errorLog.github_issue_url}" target="_blank" rel="noopener noreferrer" class="inline-flex items-center gap-1 text-gray-900 hover:text-gray-700">
            <svg class="h-5 w-5" fill="currentColor" viewBox="0 0 16 16">
              <path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0016 8c0-4.42-3.58-8-8-8z"/>
            </svg>
            <span class="font-medium">#${errorLog.github_issue_number}</span>
          </a>
        `;
      }
      return '<span class="text-gray-400">—</span>';
    }

    truncate(text, length) {
      if (!text || text.length <= length) return text || '';
      return text.substring(0, length - 3) + '...';
    }

    timeAgo(dateString) {
      const date = new Date(dateString);
      const now = new Date();
      const seconds = Math.floor((now - date) / 1000);

      const intervals = {
        year: 31536000,
        month: 2592000,
        week: 604800,
        day: 86400,
        hour: 3600,
        minute: 60
      };

      for (const [unit, secondsInUnit] of Object.entries(intervals)) {
        const interval = Math.floor(seconds / secondsInUnit);
        if (interval >= 1) {
          return `${interval} ${unit}${interval === 1 ? '' : 's'} ago`;
        }
      }

      return 'just now';
    }

    showLoading() {
      if (this.loadingIndicator) {
        this.loadingIndicator.classList.remove('hidden');
      }
    }

    hideLoading() {
      if (this.loadingIndicator) {
        this.loadingIndicator.classList.add('hidden');
      }
    }
  }

  // Initialize infinite scroll when DOM is ready
  document.addEventListener('DOMContentLoaded', function () {
    const container = document.getElementById('error-logs-container');
    if (container) {
      new InfiniteScroll(container);
    }
  });
})();
