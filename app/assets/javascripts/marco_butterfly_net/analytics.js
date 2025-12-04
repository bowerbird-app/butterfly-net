// Analytics Dashboard JavaScript
// Handles fetching data from API endpoints and rendering charts

(function() {
  'use strict';

  // Wait for DOM to load
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initializeDashboard);
  } else {
    initializeDashboard();
  }

  function initializeDashboard() {
    // Only initialize if we're on the analytics page
    if (!document.getElementById('kpi-cards')) {
      return;
    }

    fetchAndRenderAnalytics();
  }

  async function fetchAndRenderAnalytics() {
    try {
      // Fetch all data in parallel
      const [summaryData, topErrorsData, timeSeriesData] = await Promise.all([
        fetch('/marco_butterfly_net/analytics/summary').then(r => r.json()),
        fetch('/marco_butterfly_net/analytics/top_errors').then(r => r.json()),
        fetch('/marco_butterfly_net/analytics/time_series').then(r => r.json())
      ]);

      // Render all components
      renderSummaryCards(summaryData);
      renderStatusChart(summaryData.status_breakdown);
      renderTopErrorsChart(topErrorsData.top_errors);
      renderUsersChart(timeSeriesData.affected_users);
      renderOccurrencesChart(timeSeriesData.occurrences);
      renderNewErrorsChart(timeSeriesData.new_errors);
    } catch (error) {
      console.error('Failed to fetch analytics data:', error);
      showError('Failed to load analytics data. Please refresh the page.');
    }
  }

  function renderSummaryCards(data) {
    document.getElementById('kpi-open-errors').textContent = data.total_open_errors;
    document.getElementById('kpi-affected-users').textContent = data.total_affected_users_today;
    document.getElementById('kpi-occurrences').textContent = data.total_occurrences_today;
    
    const mttr = data.mean_time_to_resolution;
    const mttrText = mttr === 0 ? 'N/A' : mttr.toFixed(1) + ' hrs';
    document.getElementById('kpi-mttr').textContent = mttrText;
  }

  function renderStatusChart(statusData) {
    const statusColors = {
      'open': '#DC2626',        // red-600
      'in_progress': '#D97706', // yellow-600
      'resolved': '#059669',    // green-600
      'dismissed': '#6B7280'    // gray-500
    };

    const statusLabels = {
      'open': 'Open',
      'in_progress': 'In Progress',
      'resolved': 'Resolved',
      'dismissed': 'Dismissed'
    };

    const series = Object.values(statusData);
    const labels = Object.keys(statusData).map(key => statusLabels[key] || key);
    const colors = Object.keys(statusData).map(key => statusColors[key] || '#6B7280');

    const options = {
      series: series,
      chart: {
        type: 'donut',
        height: 300
      },
      labels: labels,
      colors: colors,
      legend: {
        position: 'bottom'
      },
      dataLabels: {
        enabled: true,
        formatter: function(val, opts) {
          return opts.w.config.series[opts.seriesIndex];
        }
      },
      plotOptions: {
        pie: {
          donut: {
            labels: {
              show: true,
              total: {
                show: true,
                label: 'Total Errors',
                formatter: function(w) {
                  return w.globals.seriesTotals.reduce((a, b) => a + b, 0);
                }
              }
            }
          }
        }
      }
    };

    const chart = new ApexCharts(document.querySelector("#status-chart"), options);
    chart.render();
  }

  function renderTopErrorsChart(topErrors) {
    if (!topErrors || topErrors.length === 0) {
      document.getElementById('top-errors-chart').innerHTML = '<p class="text-center text-gray-500">No data available</p>';
      return;
    }

    const series = [{
      name: 'Occurrences',
      data: topErrors.map(e => e.occurrence_count)
    }];

    const options = {
      series: series,
      chart: {
        type: 'bar',
        height: 300
      },
      plotOptions: {
        bar: {
          horizontal: true,
          dataLabels: {
            position: 'top'
          }
        }
      },
      dataLabels: {
        enabled: true,
        offsetX: 30,
        style: {
          fontSize: '12px'
        }
      },
      xaxis: {
        categories: topErrors.map(e => truncateText(e.exception_class, 25)),
        title: {
          text: 'Occurrences'
        }
      },
      yaxis: {
        labels: {
          style: {
            fontSize: '11px'
          }
        }
      },
      colors: ['#3B82F6'],
      tooltip: {
        custom: function({series, seriesIndex, dataPointIndex, w}) {
          const error = topErrors[dataPointIndex];
          return '<div class="px-3 py-2">' +
            '<div class="font-semibold">' + error.exception_class + '</div>' +
            '<div class="text-sm text-gray-600">' + truncateText(error.message, 50) + '</div>' +
            '<div class="text-sm mt-1">Occurrences: ' + error.occurrence_count + '</div>' +
            '</div>';
        }
      }
    };

    const chart = new ApexCharts(document.querySelector("#top-errors-chart"), options);
    chart.render();
  }

  function renderUsersChart(data) {
    if (!data || data.length === 0) {
      document.getElementById('users-chart').innerHTML = '<p class="text-center text-gray-500">No data available</p>';
      return;
    }

    const series = [{
      name: 'Affected Users',
      data: data.map(d => d.count)
    }];

    const options = {
      series: series,
      chart: {
        type: 'area',
        height: 300,
        zoom: {
          enabled: false
        }
      },
      dataLabels: {
        enabled: false
      },
      stroke: {
        curve: 'smooth',
        width: 2
      },
      fill: {
        type: 'gradient',
        gradient: {
          opacityFrom: 0.6,
          opacityTo: 0.1
        }
      },
      xaxis: {
        categories: data.map(d => formatDate(d.date)),
        labels: {
          rotate: -45,
          rotateAlways: false,
          style: {
            fontSize: '11px'
          }
        }
      },
      yaxis: {
        title: {
          text: 'Users'
        }
      },
      colors: ['#8B5CF6']
    };

    const chart = new ApexCharts(document.querySelector("#users-chart"), options);
    chart.render();
  }

  function renderOccurrencesChart(data) {
    if (!data || data.length === 0) {
      document.getElementById('occurrences-chart').innerHTML = '<p class="text-center text-gray-500">No data available</p>';
      return;
    }

    const series = [{
      name: 'Occurrences',
      data: data.map(d => d.count)
    }];

    const options = {
      series: series,
      chart: {
        type: 'line',
        height: 300,
        zoom: {
          enabled: false
        }
      },
      dataLabels: {
        enabled: false
      },
      stroke: {
        curve: 'smooth',
        width: 3
      },
      xaxis: {
        categories: data.map(d => formatDate(d.date)),
        labels: {
          rotate: -45,
          rotateAlways: false,
          style: {
            fontSize: '11px'
          }
        }
      },
      yaxis: {
        title: {
          text: 'Occurrences'
        }
      },
      colors: ['#EF4444']
    };

    const chart = new ApexCharts(document.querySelector("#occurrences-chart"), options);
    chart.render();
  }

  function renderNewErrorsChart(data) {
    if (!data || data.length === 0) {
      document.getElementById('new-errors-chart').innerHTML = '<p class="text-center text-gray-500">No data available</p>';
      return;
    }

    const series = [{
      name: 'New Errors',
      data: data.map(d => d.count)
    }];

    const options = {
      series: series,
      chart: {
        type: 'bar',
        height: 300,
        zoom: {
          enabled: false
        }
      },
      plotOptions: {
        bar: {
          columnWidth: '70%'
        }
      },
      dataLabels: {
        enabled: false
      },
      xaxis: {
        categories: data.map(d => formatDate(d.date)),
        labels: {
          rotate: -45,
          rotateAlways: false,
          style: {
            fontSize: '11px'
          }
        }
      },
      yaxis: {
        title: {
          text: 'New Errors'
        }
      },
      colors: ['#F59E0B']
    };

    const chart = new ApexCharts(document.querySelector("#new-errors-chart"), options);
    chart.render();
  }

  function formatDate(dateStr) {
    const date = new Date(dateStr);
    return (date.getMonth() + 1) + '/' + date.getDate();
  }

  function truncateText(text, maxLength) {
    if (!text) return '';
    if (text.length <= maxLength) return text;
    return text.substring(0, maxLength) + '...';
  }

  function showError(message) {
    const containers = ['kpi-cards', 'status-chart', 'top-errors-chart', 'users-chart'];
    containers.forEach(id => {
      const el = document.getElementById(id);
      if (el) {
        el.innerHTML = '<div class="text-red-600 text-center py-4">' + message + '</div>';
      }
    });
  }
})();
