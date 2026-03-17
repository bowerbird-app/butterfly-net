class AddResolvedAtToButterflyNetErrorLogs < ActiveRecord::Migration[8.1]
  def change
    add_column :butterfly_net_error_logs, :resolved_at, :datetime
    add_index :butterfly_net_error_logs, :resolved_at
  end
end
