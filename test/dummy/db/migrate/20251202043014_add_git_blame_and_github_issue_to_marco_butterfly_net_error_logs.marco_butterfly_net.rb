# frozen_string_literal: true

# This migration comes from marco_butterfly_net (originally 20251201000001)
class AddGitBlameAndGithubIssueToMarcoButterflyNetErrorLogs < ActiveRecord::Migration[8.1]
  def change
    add_column :marco_butterfly_net_error_logs, :github_issue_number, :integer
    add_column :marco_butterfly_net_error_logs, :github_issue_url, :string
    add_column :marco_butterfly_net_error_logs, :blame_file, :string
    add_column :marco_butterfly_net_error_logs, :blame_line_number, :integer
    add_column :marco_butterfly_net_error_logs, :blame_commit_sha, :string
    add_column :marco_butterfly_net_error_logs, :blame_author_name, :string
    add_column :marco_butterfly_net_error_logs, :blame_author_email, :string
    add_column :marco_butterfly_net_error_logs, :blame_commit_date, :datetime

    add_index :marco_butterfly_net_error_logs, :github_issue_number
  end
end
