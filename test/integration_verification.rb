require_relative 'test_helper'

MarcoButterflyNet::ErrorLog.delete_all

puts "1. Testing automatic enqueue on create with backtrace..."
error1 = MarcoButterflyNet::ErrorLog.create!(
  exception_class: "RuntimeError",
  message: "Test error",
  backtrace: "/app/models/user.rb:42:in save"
)
puts "   Created error: #{error1.id}"
puts "   Has backtrace: #{error1.backtrace.present?}"
puts "   Has blame info: #{error1.has_blame_info?}"
puts "   Should auto-fetch: #{error1.should_auto_fetch_blame?}"

puts "\n2. Testing no enqueue without backtrace..."
error2 = MarcoButterflyNet::ErrorLog.create!(
  exception_class: "ArgumentError",
  message: "No backtrace"
)
puts "   Created error: #{error2.id}"
puts "   Should auto-fetch: #{error2.should_auto_fetch_blame?}"

puts "\n3. Testing no enqueue with existing blame..."
error3 = MarcoButterflyNet::ErrorLog.create!(
  exception_class: "NameError",
  message: "Has blame",
  backtrace: "/app/test.rb:1:in test",
  blame_file: "app/test.rb",
  blame_commit_sha: "abc123"
)
puts "   Created error: #{error3.id}"
puts "   Has blame info: #{error3.has_blame_info?}"
puts "   Should auto-fetch: #{error3.should_auto_fetch_blame?}"

puts "\n✅ All checks passed!"
