class AddResolvedAtToMarcoButterflyNetErrorLogs < ActiveRecord::Migration[8.1]
  def change
    add_column :marco_butterfly_net_error_logs, :resolved_at, :datetime
    add_index :marco_butterfly_net_error_logs, :resolved_at
  end
end
