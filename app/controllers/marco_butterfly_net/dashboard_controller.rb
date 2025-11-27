# frozen_string_literal: true

module MarcoButterflyNet
  # Controller for the error tracking dashboard.
  # Provides index (list of errors) and show (error details) actions.
  class DashboardController < ApplicationController
    PER_PAGE = 25

    def index
      @page = (params[:page] || 1).to_i
      @page = 1 if @page < 1

      @error_logs = ErrorLog.recent
                            .offset((@page - 1) * PER_PAGE)
                            .limit(PER_PAGE)

      @total_count = ErrorLog.count
      @total_pages = (@total_count / PER_PAGE.to_f).ceil
      @total_pages = 1 if @total_pages < 1
    end

    def show
      @error_log = ErrorLog.find(params[:id])
    end
  end
end
