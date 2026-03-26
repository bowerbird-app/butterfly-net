# frozen_string_literal: true

class CreateButterflyNetErrorLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :butterfly_net_error_logs do |t|
      t.string :exception_class, null: false
      t.text :message
      t.text :backtrace
      t.json :request_params
      t.string :user_agent

      t.timestamps
    end

    add_index :butterfly_net_error_logs, :exception_class
    add_index :butterfly_net_error_logs, :created_at
  end
end
