# frozen_string_literal: true

class AddUserTrackingToMarcoButterflyNetErrorLogs < ActiveRecord::Migration[8.1]
  def change
    add_column :marco_butterfly_net_error_logs, :user_id, :uuid
    add_column :marco_butterfly_net_error_logs, :user_email, :string
    add_column :marco_butterfly_net_error_logs, :occurrence_count, :integer, default: 1, null: false
    add_column :marco_butterfly_net_error_logs, :status, :string, default: "open", null: false

    add_index :marco_butterfly_net_error_logs, :user_id
    add_index :marco_butterfly_net_error_logs, :user_email
    add_index :marco_butterfly_net_error_logs, :status
  end
end
