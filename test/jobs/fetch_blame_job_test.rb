# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class ButterflyNet::FetchBlameJobTest < ActiveJob::TestCase
  setup do
    ButterflyNet::ErrorOccurrence.delete_all
    ButterflyNet::ErrorLog.delete_all
  end

  test "successfully fetches blame info for an error log" do
    # Create error log with backtrace but no blame info
    error_log = ButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error",
      backtrace: "/app/models/user.rb:42:in `save'\n/app/controllers/users_controller.rb:10:in `create'"
    )

    # Clear any existing blame info to simulate fresh error
    error_log.update_columns(
      blame_file: nil,
      blame_line_number: nil,
      blame_commit_sha: nil,
      blame_author_name: nil,
      blame_author_email: nil,
      blame_commit_date: nil
    )

    # Mock the GitBlame service to return a BlameResult
    blame_result = ButterflyNet::Services::GitBlame::BlameResult.new(
      file: "app/models/user.rb",
      line_number: 42,
      commit_sha: "abc123",
      author_name: "Test Author",
      author_email: "test@example.com",
      commit_date: Time.current,
      line_content: "def save"
    )

    service_mock = Minitest::Mock.new
    service_mock.expect(:blame_from_backtrace, blame_result, [ error_log.backtrace_lines ])

    ButterflyNet::Services::GitBlame.stub(:new, service_mock) do
      # Perform the job
      ButterflyNet::FetchBlameJob.perform_now(error_log.id)
    end

    # Verify blame fields are populated
    error_log.reload
    assert_equal "app/models/user.rb", error_log.blame_file
    assert_equal 42, error_log.blame_line_number
    assert_equal "abc123", error_log.blame_commit_sha
    assert_equal "Test Author", error_log.blame_author_name
    assert_equal "test@example.com", error_log.blame_author_email
    assert_not_nil error_log.blame_commit_date

    service_mock.verify
  end

  test "skips fetching if blame info already exists" do
    # Create error log with existing blame info
    error_log = ButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error",
      backtrace: "/app/models/user.rb:42:in `save'",
      blame_file: "app/models/user.rb",
      blame_line_number: 42,
      blame_commit_sha: "existing123",
      blame_author_name: "Existing Author",
      blame_author_email: "existing@example.com",
      blame_commit_date: 1.day.ago
    )

    # Store original values
    original_sha = error_log.blame_commit_sha
    original_author = error_log.blame_author_name

    # Perform the job
    ButterflyNet::FetchBlameJob.perform_now(error_log.id)

    # Verify blame info wasn't changed (job skipped)
    error_log.reload
    assert_equal original_sha, error_log.blame_commit_sha
    assert_equal original_author, error_log.blame_author_name
  end

  test "handles missing error logs gracefully" do
    # Use a non-existent ID
    non_existent_id = 999999

    # Should not raise any errors
    assert_nothing_raised do
      ButterflyNet::FetchBlameJob.perform_now(non_existent_id)
    end
  end

  test "handles git errors gracefully" do
    # Create error log with backtrace
    error_log = ButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error",
      backtrace: "/app/models/user.rb:42:in `save'"
    )

    # Mock GitBlame service to raise an error
    service_mock = Minitest::Mock.new
    service_mock.expect(:blame_from_backtrace, nil) do
      raise StandardError, "Git command failed"
    end

    ButterflyNet::Services::GitBlame.stub(:new, service_mock) do
      # Should not raise any errors (error is caught and logged)
      assert_nothing_raised do
        ButterflyNet::FetchBlameJob.perform_now(error_log.id)
      end
    end
  end

  test "handles nil backtrace gracefully" do
    error_log = ButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error",
      backtrace: nil
    )

    # Should not raise any errors
    assert_nothing_raised do
      ButterflyNet::FetchBlameJob.perform_now(error_log.id)
    end

    # Verify no blame info was set
    error_log.reload
    assert_not error_log.has_blame_info?
  end

  test "can be enqueued" do
    error_log = ButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error",
      backtrace: "/app/models/user.rb:42:in `save'"
    )

    assert_enqueued_with(job: ButterflyNet::FetchBlameJob, args: [ error_log.id ]) do
      ButterflyNet::FetchBlameJob.perform_later(error_log.id)
    end
  end
end
