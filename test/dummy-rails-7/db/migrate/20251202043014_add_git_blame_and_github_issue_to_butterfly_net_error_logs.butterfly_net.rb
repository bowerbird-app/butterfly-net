# frozen_string_literal: true

# This migration comes from butterfly_net (originally 20251201000001)
class AddGitBlameAndGithubIssueToButterflyNetErrorLogs < ActiveRecord::Migration[7.1]
  def change
    add_column :butterfly_net_error_logs, :github_issue_number, :integer
    add_column :butterfly_net_error_logs, :github_issue_url, :string
    add_column :butterfly_net_error_logs, :blame_file, :string
    add_column :butterfly_net_error_logs, :blame_line_number, :integer
    add_column :butterfly_net_error_logs, :blame_commit_sha, :string
    add_column :butterfly_net_error_logs, :blame_author_name, :string
    add_column :butterfly_net_error_logs, :blame_author_email, :string
    add_column :butterfly_net_error_logs, :blame_commit_date, :datetime

    add_index :butterfly_net_error_logs, :github_issue_number
  end
end
