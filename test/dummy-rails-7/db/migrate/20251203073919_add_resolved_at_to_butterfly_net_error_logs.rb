# frozen_string_literal: true

# This migration comes from butterfly_net (originally 20251203073003)
class AddResolvedAtToButterflyNetErrorLogs < ActiveRecord::Migration[7.1]
  def change
    add_column :butterfly_net_error_logs, :resolved_at, :datetime
    add_index :butterfly_net_error_logs, :resolved_at
  end
end
