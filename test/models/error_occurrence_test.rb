# frozen_string_literal: true

require "test_helper"

class ButterflyNet::ErrorOccurrenceTest < ActiveSupport::TestCase
  setup do
    ButterflyNet::ErrorOccurrence.delete_all
    ButterflyNet::ErrorLog.delete_all
  end

  test "belongs to error_log" do
    error_log = ButterflyNet::ErrorLog.create!(exception_class: "RuntimeError")
    occurrence = ButterflyNet::ErrorOccurrence.create!(
      error_log: error_log,
      user_id: SecureRandom.uuid,
      user_email: "test@example.com"
    )

    assert_equal error_log, occurrence.error_log
  end

  test "stores user information" do
    error_log = ButterflyNet::ErrorLog.create!(exception_class: "RuntimeError")
    user_id = SecureRandom.uuid

    occurrence = ButterflyNet::ErrorOccurrence.create!(
      error_log: error_log,
      user_id: user_id,
      user_email: "test@example.com",
      user_agent: "Test Browser"
    )

    assert_equal user_id, occurrence.user_id
    assert_equal "test@example.com", occurrence.user_email
    assert_equal "Test Browser", occurrence.user_agent
  end

  test "stores request_params" do
    error_log = ButterflyNet::ErrorLog.create!(exception_class: "RuntimeError")
    occurrence = ButterflyNet::ErrorOccurrence.create!(
      error_log: error_log,
      request_params: { path: "/test", method: "GET" }
    )

    assert_equal({ "path" => "/test", "method" => "GET" }, occurrence.request_params)
  end

  test "params_hash returns request_params or empty hash" do
    error_log = ButterflyNet::ErrorLog.create!(exception_class: "RuntimeError")

    occurrence_with_params = ButterflyNet::ErrorOccurrence.new(
      error_log: error_log,
      request_params: { path: "/test" }
    )

    occurrence_without_params = ButterflyNet::ErrorOccurrence.new(
      error_log: error_log,
      request_params: nil
    )

    assert_equal({ "path" => "/test" }, occurrence_with_params.params_hash)
    assert_equal({}, occurrence_without_params.params_hash)
  end

  test "recent scope orders by created_at desc" do
    error_log = ButterflyNet::ErrorLog.create!(exception_class: "RuntimeError")

    old_occurrence = ButterflyNet::ErrorOccurrence.create!(
      error_log: error_log,
      created_at: 1.day.ago
    )

    new_occurrence = ButterflyNet::ErrorOccurrence.create!(
      error_log: error_log,
      created_at: Time.current
    )

    recent = ButterflyNet::ErrorOccurrence.recent

    assert_equal new_occurrence, recent.first
    assert_equal old_occurrence, recent.last
  end

  test "for_user scope filters by user_id" do
    error_log = ButterflyNet::ErrorLog.create!(exception_class: "RuntimeError")
    user_id = SecureRandom.uuid
    other_user_id = SecureRandom.uuid

    ButterflyNet::ErrorOccurrence.create!(error_log: error_log, user_id: user_id)
    ButterflyNet::ErrorOccurrence.create!(error_log: error_log, user_id: other_user_id)
    ButterflyNet::ErrorOccurrence.create!(error_log: error_log, user_id: user_id)

    user_occurrences = ButterflyNet::ErrorOccurrence.for_user(user_id)

    assert_equal 2, user_occurrences.count
    assert user_occurrences.all? { |o| o.user_id == user_id }
  end

  test "for_user_email scope filters by user_email" do
    error_log = ButterflyNet::ErrorLog.create!(exception_class: "RuntimeError")

    ButterflyNet::ErrorOccurrence.create!(error_log: error_log, user_email: "user1@example.com")
    ButterflyNet::ErrorOccurrence.create!(error_log: error_log, user_email: "user2@example.com")
    ButterflyNet::ErrorOccurrence.create!(error_log: error_log, user_email: "user1@example.com")

    user_occurrences = ButterflyNet::ErrorOccurrence.for_user_email("user1@example.com")

    assert_equal 2, user_occurrences.count
    assert user_occurrences.all? { |o| o.user_email == "user1@example.com" }
  end

  test "tracks timestamp for each occurrence" do
    error_log = ButterflyNet::ErrorLog.create!(exception_class: "RuntimeError")

    occurrence = ButterflyNet::ErrorOccurrence.create!(
      error_log: error_log,
      user_id: SecureRandom.uuid
    )

    assert_not_nil occurrence.created_at
    assert_not_nil occurrence.updated_at
  end

  test "can be created without user_id" do
    error_log = ButterflyNet::ErrorLog.create!(exception_class: "RuntimeError")

    occurrence = ButterflyNet::ErrorOccurrence.create!(error_log: error_log)

    assert occurrence.persisted?
    assert_nil occurrence.user_id
  end

  test "can be created without user_email" do
    error_log = ButterflyNet::ErrorLog.create!(exception_class: "RuntimeError")

    occurrence = ButterflyNet::ErrorOccurrence.create!(error_log: error_log)

    assert occurrence.persisted?
    assert_nil occurrence.user_email
  end

  test "for_user returns empty when user_id is nil" do
    error_log = ButterflyNet::ErrorLog.create!(exception_class: "RuntimeError")
    ButterflyNet::ErrorOccurrence.create!(error_log: error_log, user_id: "user1")

    user_occurrences = ButterflyNet::ErrorOccurrence.for_user(nil)

    assert_equal 0, user_occurrences.count
  end

  test "for_user_email returns empty when email is nil" do
    error_log = ButterflyNet::ErrorLog.create!(exception_class: "RuntimeError")
    ButterflyNet::ErrorOccurrence.create!(error_log: error_log, user_email: "user@example.com")

    user_occurrences = ButterflyNet::ErrorOccurrence.for_user_email(nil)

    assert_equal 0, user_occurrences.count
  end
end
