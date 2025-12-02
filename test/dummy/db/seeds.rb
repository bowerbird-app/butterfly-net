# frozen_string_literal: true

# Seed file for MarcoButterflyNet test/demo data
#
# This file creates sample error logs and occurrences to demonstrate all features:
# - Multiple error types (NoMethodError, ActiveRecord::RecordNotFound, etc.)
# - Different error statuses (open, in_progress, resolved, dismissed)
# - Multiple occurrences per error from different users
# - Git blame information
# - GitHub issue integration
#
# To use in your own app:
#   1. Copy this file: cp $(bundle show marco_butterfly_net)/test/dummy/db/seeds.rb db/marco_butterfly_net_seeds.rb
#   2. Run it: bin/rails runner db/marco_butterfly_net_seeds.rb

# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "Seeding test data for MarcoButterflyNet..."

# Clear existing data
MarcoButterflyNet::ErrorOccurrence.delete_all
MarcoButterflyNet::ErrorLog.delete_all

# Sample data for variety
exception_classes = [
  "NoMethodError", "ActiveRecord::RecordNotFound", "ArgumentError",
  "ZeroDivisionError", "NameError", "TypeError", "RuntimeError",
  "ActiveRecord::RecordInvalid", "ActionController::ParameterMissing",
  "JSON::ParserError", "Errno::ENOENT", "Net::ReadTimeout"
]

statuses = [ "open", "in_progress", "resolved", "dismissed" ]

controllers = [
  "users", "posts", "comments", "orders", "products", "payments",
  "notifications", "sessions", "admin", "api/v1/resources"
]

actions = [ "index", "show", "create", "update", "destroy" ]

authors = [
  { name: "Jane Developer", email: "jane@example.com" },
  { name: "John Smith", email: "john@example.com" },
  { name: "Alice Johnson", email: "alice@example.com" },
  { name: "Bob Wilson", email: "bob@example.com" },
  { name: "Charlie Brown", email: "charlie@example.com" }
]

# Create 50 different error logs
errors = []
50.times do |i|
  exception_class = exception_classes.sample
  controller = controllers.sample
  action = actions.sample
  status = statuses.sample
  author = authors.sample

  # Generate variety in messages
  messages = case exception_class
  when "NoMethodError"
    [
      "undefined method `#{[ 'name', 'email', 'title', 'status', 'price' ].sample}' for nil:NilClass",
      "undefined method `#{[ 'user', 'post', 'comment', 'order' ].sample}' for #<#{controller.capitalize}Controller>",
      "private method `#{[ 'update_status', 'send_email', 'calculate' ].sample}' called"
    ]
  when "ActiveRecord::RecordNotFound"
    resource = controller.capitalize.singularize
    [ "Couldn't find #{resource} with 'id'=#{rand(100..999)}",
     "Couldn't find #{resource} without an ID" ]
  when "ArgumentError"
    [ "wrong number of arguments (given #{rand(0..3)}, expected #{rand(1..3)})",
     "invalid value for #{[ 'Integer', 'Float', 'Date' ].sample}(): \"invalid\"" ]
  when "ActiveRecord::RecordInvalid"
    [ "Validation failed: #{[ 'Email', 'Name', 'Title', 'Price' ].sample} can't be blank",
     "Validation failed: #{[ 'Email', 'Username' ].sample} has already been taken" ]
  when "ActionController::ParameterMissing"
    [ "param is missing or the value is empty: #{controller.singularize}" ]
  when "JSON::ParserError"
    [ "unexpected token at '{invalid json}'",
     "A JSON text must at least contain two octets!" ]
  when "Errno::ENOENT"
    [ "No such file or directory @ rb_sysopen - #{[ '/tmp/upload', '/var/log/app', '/data/export' ].sample}.txt" ]
  when "Net::ReadTimeout"
    [ "Net::ReadTimeout with #<TCPSocket:(closed)>" ]
  else
    [ "#{exception_class} occurred in #{controller}##{action}" ]
  end

  # Add git blame info for some errors
  has_blame = [ true, false, false ].sample
  blame_attrs = if has_blame
    {
      blame_file: "app/controllers/#{controller}_controller.rb",
      blame_line_number: rand(1..100),
      blame_commit_sha: SecureRandom.hex(20),
      blame_author_name: author[:name],
      blame_author_email: author[:email],
      blame_commit_date: rand(1..60).days.ago
    }
  else
    {}
  end

  # Add GitHub issue for some errors
  has_github = [ true, false, false, false ].sample
  github_attrs = if has_github
    issue_num = rand(1..200)
    {
      github_issue_number: issue_num,
      github_issue_url: "https://github.com/example/repo/issues/#{issue_num}"
    }
  else
    {}
  end

  errors << MarcoButterflyNet::ErrorLog.create!(
    exception_class: exception_class,
    message: messages.sample,
    backtrace: "/app/controllers/#{controller}_controller.rb:#{rand(1..100)}:in `#{action}'\n/app/controllers/application_controller.rb:#{rand(1..50)}:in `process_action'\n/gems/actionpack-8.1.0/lib/action_controller/metal/basic_implicit_render.rb:8:in `send_action'",
    status: status,
    **blame_attrs,
    **github_attrs
  )
end

puts "Created #{MarcoButterflyNet::ErrorLog.count} error logs"

# Create multiple occurrences for each error to simulate real usage
users = [
  { id: "user_001", email: "alice@example.com" },
  { id: "user_002", email: "bob@example.com" },
  { id: "user_003", email: "charlie@example.com" },
  { id: "user_004", email: "diana@example.com" },
  { id: "user_005", email: "eve@example.com" },
  { id: "user_006", email: "frank@example.com" },
  { id: "user_007", email: "grace@example.com" },
  { id: nil, email: nil } # Anonymous user
]

user_agents = [
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
  "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36",
  "Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15",
  "Mozilla/5.0 (iPad; CPU OS 14_7_1 like Mac OS X) AppleWebKit/605.1.15",
  "Mozilla/5.0 (Android 12; Mobile) AppleWebKit/537.36"
]

# Create occurrences for each error with varying frequency
errors.each_with_index do |error, index|
  # Vary the number of occurrences:
  # - Some errors are rare (1-2 occurrences)
  # - Some are common (10-20 occurrences)
  # - Some are very frequent (30-50 occurrences)
  occurrence_count = case index % 5
  when 0 then 1  # 20% rare errors
  when 1 then rand(2..5)  # 20% occasional errors
  when 2 then rand(6..12)  # 20% moderate errors
  when 3 then rand(13..25)  # 20% common errors
  when 4 then rand(26..50)  # 20% very frequent errors
  end

  occurrence_count.times do |occ_idx|
    user = users.sample

    # Create request params based on the error's controller/action
    controller = controllers.sample
    action = actions.sample

    request_params = {
      path: "/#{controller}/#{rand(1..100)}",
      method: [ "GET", "POST", "PUT", "PATCH", "DELETE" ].sample,
      controller: controller,
      action: action
    }

    # Add action-specific params
    case action
    when "show", "update", "destroy"
      request_params[:id] = rand(1..100).to_s
    when "create"
      request_params[controller.singularize.to_sym] = {
        name: "Test #{controller.singularize.capitalize}",
        status: [ "active", "pending", "completed" ].sample
      }
    when "index"
      request_params[:page] = rand(1..10).to_s
      request_params[:per_page] = [ 10, 25, 50, 100 ].sample.to_s
    end

    # Vary the time distribution of occurrences
    created_at = if occurrence_count > 20
      # Frequent errors: spread over last 7 days
      rand(0..7).days.ago + rand(0..23).hours
    elsif occurrence_count > 10
      # Common errors: spread over last 14 days
      rand(0..14).days.ago + rand(0..23).hours
    else
      # Rare errors: spread over last 30 days
      rand(0..30).days.ago + rand(0..23).hours
    end

    error.occurrences.create!(
      user_id: user[:id],
      user_email: user[:email],
      request_params: request_params,
      user_agent: user_agents.sample,
      created_at: created_at
    )
  end
end

puts "Created #{MarcoButterflyNet::ErrorOccurrence.count} error occurrences"


# Print summary
puts "\n=== Summary ==="
puts "Total Errors: #{MarcoButterflyNet::ErrorLog.count}"
puts "  - Open: #{MarcoButterflyNet::ErrorLog.open.count}"
puts "  - In Progress: #{MarcoButterflyNet::ErrorLog.with_status('in_progress').count}"
puts "  - Resolved: #{MarcoButterflyNet::ErrorLog.resolved.count}"
puts "  - Dismissed: #{MarcoButterflyNet::ErrorLog.with_status('dismissed').count}"
puts "\nTotal Occurrences: #{MarcoButterflyNet::ErrorOccurrence.count}"
puts "Repeated Errors: #{MarcoButterflyNet::ErrorLog.repeated.count}"
puts "\nErrors by exception class:"
MarcoButterflyNet::ErrorLog.group(:exception_class).count.each do |exception_class, count|
  puts "  - #{exception_class}: #{count}"
end

puts "\nSeed data created successfully!"
