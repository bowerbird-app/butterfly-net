# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2025_12_03_073919) do
  create_table "butterfly_net_error_logs", force: :cascade do |t|
    t.string "exception_class", null: false
    t.text "message"
    t.text "backtrace"
    t.json "request_params"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "github_issue_number"
    t.string "github_issue_url"
    t.string "blame_file"
    t.integer "blame_line_number"
    t.string "blame_commit_sha"
    t.string "blame_author_name"
    t.string "blame_author_email"
    t.datetime "blame_commit_date"
    t.string "status", default: "open", null: false
    t.datetime "resolved_at"
    t.index ["created_at"], name: "index_butterfly_net_error_logs_on_created_at"
    t.index ["exception_class"], name: "index_butterfly_net_error_logs_on_exception_class"
    t.index ["github_issue_number"], name: "index_butterfly_net_error_logs_on_github_issue_number"
    t.index ["resolved_at"], name: "index_butterfly_net_error_logs_on_resolved_at"
    t.index ["status"], name: "index_butterfly_net_error_logs_on_status"
  end

  create_table "butterfly_net_error_occurrences", force: :cascade do |t|
    t.integer "error_log_id", null: false
    t.string "user_id"
    t.string "user_email"
    t.json "request_params"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_butterfly_net_error_occurrences_on_created_at"
    t.index ["error_log_id"], name: "index_butterfly_net_error_occurrences_on_error_log_id"
    t.index ["user_email"], name: "index_butterfly_net_error_occurrences_on_user_email"
    t.index ["user_id"], name: "index_butterfly_net_error_occurrences_on_user_id"
  end

  add_foreign_key "butterfly_net_error_occurrences", "butterfly_net_error_logs", column: "error_log_id"
end
