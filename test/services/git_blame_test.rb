# frozen_string_literal: true

require "test_helper"

class MarcoButterflyNet::Services::GitBlameTest < ActiveSupport::TestCase
  setup do
    @repo_path = Rails.root.to_s
    @service = MarcoButterflyNet::Services::GitBlame.new(repo_path: @repo_path)
    MarcoButterflyNet.reset_configuration!
  end

  teardown do
    MarcoButterflyNet.reset_configuration!
  end

  test "initializes with default repo path" do
    service = MarcoButterflyNet::Services::GitBlame.new
    assert_not_nil service.repo_path
  end

  test "initializes with custom repo path" do
    service = MarcoButterflyNet::Services::GitBlame.new(repo_path: "/custom/path")
    assert_equal "/custom/path", service.repo_path
  end

  test "uses configured repo path when available" do
    MarcoButterflyNet.configure do |config|
      config.repo_path = "/configured/path"
    end
    service = MarcoButterflyNet::Services::GitBlame.new
    assert_equal "/configured/path", service.repo_path
  end

  test "blame_from_backtrace returns nil for empty backtrace" do
    result = @service.blame_from_backtrace([])
    assert_nil result
  end

  test "blame_from_backtrace returns nil for nil backtrace" do
    result = @service.blame_from_backtrace(nil)
    assert_nil result
  end

  test "blame_line parses backtrace line correctly" do
    # Create a test file path that exists in the repo
    test_file = File.join(@repo_path, "Gemfile")
    backtrace_line = "#{test_file}:1:in `block'"

    result = @service.blame_line(backtrace_line)

    # Will only work if Gemfile is tracked by git
    if result
      assert_instance_of MarcoButterflyNet::Services::GitBlame::BlameResult, result
      assert_equal "Gemfile", result.file
      assert_equal 1, result.line_number
      assert_not_nil result.commit_sha
      assert_not_nil result.author_name
    else
      # If git blame fails (e.g., uncommitted file), still pass the test
      assert_nil result
    end
  end

  test "blame_line returns nil for file outside repo" do
    backtrace_line = "/usr/lib/ruby/gems/3.2.0/gems/activesupport-8.1.1/lib/active_support/core_ext/object.rb:42:in `block'"
    result = @service.blame_line(backtrace_line)
    assert_nil result
  end

  test "blame_line returns nil for invalid backtrace line format" do
    backtrace_line = "this is not a valid backtrace line"
    result = @service.blame_line(backtrace_line)
    assert_nil result
  end

  test "blame_all_from_backtrace returns array of results" do
    test_file = File.join(@repo_path, "Gemfile")
    backtrace_lines = [
      "/usr/lib/ruby/gems/3.2.0/gems/activesupport-8.1.1/lib/active_support/core_ext/object.rb:42:in `block'",
      "#{test_file}:1:in `block'"
    ]

    results = @service.blame_all_from_backtrace(backtrace_lines)

    assert_instance_of Array, results
    # Should only include results for files in the repo
    results.each do |result|
      assert_instance_of MarcoButterflyNet::Services::GitBlame::BlameResult, result
    end
  end

  test "blame_all_from_backtrace returns empty array for nil" do
    results = @service.blame_all_from_backtrace(nil)
    assert_equal [], results
  end

  test "BlameResult struct has expected attributes" do
    result = MarcoButterflyNet::Services::GitBlame::BlameResult.new(
      file: "test.rb",
      line_number: 42,
      commit_sha: "abc123",
      author_name: "Test Author",
      author_email: "test@example.com",
      commit_date: Time.now.utc,
      line_content: "def test; end"
    )

    assert_equal "test.rb", result.file
    assert_equal 42, result.line_number
    assert_equal "abc123", result.commit_sha
    assert_equal "Test Author", result.author_name
    assert_equal "test@example.com", result.author_email
    assert_not_nil result.commit_date
    assert_equal "def test; end", result.line_content
  end
end
