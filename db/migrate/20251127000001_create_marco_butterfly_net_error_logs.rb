# frozen_string_literal: true

class CreateMarcoButterflyNetErrorLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :marco_butterfly_net_error_logs do |t|
      t.string :exception_class, null: false
      t.text :message
      t.text :backtrace
      t.json :request_params
      t.string :user_agent

      t.timestamps
    end

    add_index :marco_butterfly_net_error_logs, :exception_class
    add_index :marco_butterfly_net_error_logs, :created_at
  end
end
