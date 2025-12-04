# frozen_string_literal: true

module MarcoButterflyNet
  # Background job to fetch git blame information for an error log.
  # Runs asynchronously to avoid slowing down error tracking.
  class FetchBlameJob < ApplicationJob
    queue_as :default

    retry_on StandardError, wait: 5.seconds, attempts: 3

    # Fetch blame information for the given error log
    # @param error_log_id [Integer] the ID of the error log to fetch blame for
    def perform(error_log_id)
      error_log = MarcoButterflyNet::ErrorLog.find_by(id: error_log_id)
      return unless error_log

      # Skip if blame info already exists
      return if error_log.has_blame_info?

      # Fetch and store blame information
      error_log.fetch_blame_info
    rescue StandardError => e
      # Log the error but don't re-raise since blame fetching is non-critical
      Rails.logger.error("[MarcoButterflyNet] FetchBlameJob failed for error_log_id=#{error_log_id}: #{e.message}")
    end
  end
end
