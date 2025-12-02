# frozen_string_literal: true

# This migration comes from marco_butterfly_net (originally 20251202000001)
class AddUserTrackingToMarcoButterflyNetErrorLogs < ActiveRecord::Migration[8.1]
  def change
    # Add status to error_logs for tracking bug status
    add_column :marco_butterfly_net_error_logs, :status, :string, default: "open", null: false
    add_index :marco_butterfly_net_error_logs, :status

    # Create error_occurrences table for tracking individual occurrences
    # This allows grouping same errors while tracking user info and timing separately
    create_table :marco_butterfly_net_error_occurrences do |t|
      t.references :error_log, null: false, foreign_key: { to_table: :marco_butterfly_net_error_logs }
      t.string :user_id
      t.string :user_email
      t.json :request_params
      t.string :user_agent

      t.timestamps
    end

    add_index :marco_butterfly_net_error_occurrences, :user_id
    add_index :marco_butterfly_net_error_occurrences, :user_email
    add_index :marco_butterfly_net_error_occurrences, :created_at
  end
end
