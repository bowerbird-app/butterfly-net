# ButterflyNet

ButterflyNet is a self-hosted error tracking dashboard for Rails applications. It's built as a mountable Rails engine that uses Rack middleware to intercept exceptions from the entire Rails stack.

## Features

- **Mountable Engine**: Mount it at any path in your Rails application
- **Namespace Isolation**: Uses `isolate_namespace` for clean separation
- **Rack Middleware**: Catches exceptions from the entire stack, not just controller errors
- **Persistent Storage**: Stores errors in a database table (namespaced to avoid conflicts)
- **Dashboard UI**: Clean, paginated interface to browse and inspect errors
- **Tailwind CSS Styling**: Uses Tailwind CSS v4 for a modern, responsive design that won't conflict with host application styles
- **User Tracking**: Track which users are affected by each error with separate occurrence records
- **Error Status Management**: Track bug resolution status (open, in_progress, resolved, dismissed)
- **Git Blame Integration**: Identify who introduced the code that caused an error
- **GitHub Issue Integration**: Create GitHub issues directly from the error dashboard

## Installation

Add this line to your application's Gemfile:

```ruby
gem "butterfly_net"
```

And then execute:

```bash
bundle install
```

Run the migration to create the error logs table:

```bash
bin/rails butterfly_net:install:migrations
bin/rails db:migrate
```

## Upgrading from v0.3.0 to v0.4.0

If you're upgrading from v0.3.0 to v0.4.0 with user tracking and error status features, follow these steps:

### 1. Run the New Migration (Required)

```bash
bin/rails butterfly_net:install:migrations
bin/rails db:migrate
```

This migration will:
- Add a `status` column to existing error logs (defaults to "open")
- Create the new `error_occurrences` table to track individual error instances
- Add indexes for efficient querying by user, status, and timestamp

**Important**: Existing error logs will remain intact but won't have occurrence records. Only new errors after the migration will properly track occurrences.

### 2. Add User Tracking (Optional but Recommended)

To track which users are affected by errors, add this to your `ApplicationController` or a concern:

```ruby
around_action :set_error_tracking_context

private

def set_error_tracking_context
  # Store user info in request.env for error tracking
  request.env["error_tracking.user_id"] = current_user&.id
  request.env["error_tracking.user_email"] = current_user&.email
  yield
end
```

**Without this setup**: The gem will continue to work normally, but won't capture user information for errors.

**With this setup**: You'll be able to:
- See which users are affected by each error
- Filter errors by user ID or email
- Track the number of unique users impacted
- View the complete timeline of error occurrences

### 3. No Breaking Changes

The upgrade is backward compatible - no code changes are required for existing functionality to continue working.

### Testing with Sample Data

To quickly test the dashboard with sample error data, you can use the seed file from the dummy app:

```bash
# Copy the seed file to your app
cp $(bundle show butterfly_net)/test/dummy/db/seeds.rb db/butterfly_net_seeds.rb

# Run it
bin/rails runner db/butterfly_net_seeds.rb
```

This will create:
- 5 different error types with various statuses (open, in_progress, resolved, dismissed)
- 26 error occurrences across different users
- Sample data showing git blame and GitHub issue integration

## Usage

### Basic Setup

Mount the engine in your `config/routes.rb`:

```ruby
Rails.application.routes.draw do
  mount ButterflyNet::Engine, at: "/errors"
end
```

The middleware is automatically inserted into your Rails middleware stack when the engine is loaded.

## Security (IMPORTANT)

**The engine does not include any authentication or authorization by default.** The dashboard is accessible to anyone who can reach the mounted path. This is by design - the host application is responsible for securing access to the dashboard.

### Securing with Devise

If you're using Devise, wrap the mount in an `authenticate` block:

```ruby
Rails.application.routes.draw do
  # Only authenticated admins can access the error dashboard
  authenticate :user, ->(user) { user.admin? } do
    mount ButterflyNet::Engine, at: "/errors"
  end
end
```

### Securing with HTTP Basic Auth

For simple protection, you can use HTTP Basic Auth:

```ruby
Rails.application.routes.draw do
  mount ButterflyNet::Engine, at: "/errors", constraints: ->(request) {
    Rack::Auth::Basic::Request.new(request.env).credentials == ['admin', 'secret']
  }
end
```

### Securing with Custom Constraints

Use a custom constraint class for more complex logic:

```ruby
# lib/admin_constraint.rb
class AdminConstraint
  def matches?(request)
    return false unless request.session[:user_id]
    User.find(request.session[:user_id])&.admin?
  end
end

# config/routes.rb
Rails.application.routes.draw do
  constraints AdminConstraint.new do
    mount ButterflyNet::Engine, at: "/errors"
  end
end
```

### Restricting to Internal Networks

For additional security, restrict access to internal networks:

```ruby
Rails.application.routes.draw do
  constraints ->(request) { ['127.0.0.1', '::1'].include?(request.remote_ip) } do
    mount ButterflyNet::Engine, at: "/errors"
  end
end
```

## Data Model

The engine creates two main tables to track errors and their occurrences:

### Error Logs Table (`butterfly_net_error_logs`)

Stores unique error types with their metadata:

| Field | Type | Description |
|-------|------|-------------|
| `exception_class` | string | The class name of the exception (e.g., `NoMethodError`) |
| `message` | text | The exception message |
| `backtrace` | text | The full stack trace |
| `status` | string | Error status: `open`, `in_progress`, `resolved`, or `dismissed` (default: `open`) |
| `blame_file` | string | File path from git blame analysis |
| `blame_line_number` | integer | Line number from git blame |
| `blame_commit_sha` | string | Git commit SHA that introduced the code |
| `blame_author_name` | string | Author name from git blame |
| `blame_author_email` | string | Author email from git blame |
| `blame_commit_date` | datetime | Commit date from git blame |
| `github_issue_number` | integer | Associated GitHub issue number |
| `github_issue_url` | string | Associated GitHub issue URL |
| `created_at` | datetime | When the error type was first seen |
| `updated_at` | datetime | When the error was last updated |

### Error Occurrences Table (`butterfly_net_error_occurrences`)

Tracks individual instances of each error type with user context:

| Field | Type | Description |
|-------|------|-------------|
| `error_log_id` | bigint | Foreign key to `butterfly_net_error_logs` |
| `user_id` | string | The ID of the user who encountered the error (if available) |
| `user_email` | string | The email of the user who encountered the error (if available) |
| `request_params` | json | Request details (path, method, query string, params) |
| `user_agent` | string | The client's User-Agent header |
| `created_at` | datetime | When this specific occurrence happened |
| `updated_at` | datetime | When this occurrence was last updated |

This separation allows you to:
- Group identical errors together while tracking each occurrence separately
- See how many times an error occurred and when
- Identify which users are affected by specific errors
- Track error resolution status independently from occurrences

## Architecture

### Mountable Engine

ButterflyNet is built as a mountable Rails engine using `--mountable`, providing:
- Isolated routes scoped under a mount point
- Namespaced controllers, models, and views
- Separate asset pipeline

### Namespace Isolation

The engine uses `isolate_namespace ButterflyNet` to prevent naming conflicts with the host application's code.

### Exception Catching

ButterflyNet catches exceptions through two complementary mechanisms:

#### 1. Rack Middleware

The `ButterflyNet::Middleware::ExceptionCatcher` is inserted at the top of the middleware stack to intercept exceptions that propagate up:

```ruby
# Automatically configured by the engine
app.middleware.insert_before(0, ButterflyNet::Middleware::ExceptionCatcher)
```

#### 2. DebugExceptions Interceptor

Rails' `ActionDispatch::DebugExceptions` middleware renders error pages without re-raising exceptions. To capture these errors (like `NameError`, `NoMethodError`, etc.), we register an interceptor:

```ruby
# Automatically configured by the engine
ActionDispatch::DebugExceptions.register_interceptor do |request, exception|
  ButterflyNet::Middleware::ExceptionCatcher.handle_intercepted_exception(exception, request.env)
end
```

Together, these mechanisms ensure all exceptions are caught from the entire request/response cycle, including:
- Controller errors (e.g., `NameError`, `NoMethodError`)
- Model/ActiveRecord errors
- View/template errors
- Routing errors
- Other middleware errors

## Git Blame Integration

ButterflyNet can identify who introduced the code that caused an error by using `git blame`. From the error dashboard, you can fetch blame information for any error, which will show:

- The file and line number where the error originated
- The commit SHA that introduced the code
- The author's name and email
- The date of the commit

### Automatic Blame Fetching

Git blame information is automatically fetched in the background when new errors are logged. This happens asynchronously using ActiveJob, so it doesn't slow down your application when errors occur.

The gem works with whatever ActiveJob backend your application uses:
- **Development**: Uses Rails' built-in async adapter by default
- **Production**: Works seamlessly with Sidekiq, Solid Queue, GoodJob, Resque, Delayed Job, or any other ActiveJob adapter

**No configuration is required.** The automatic blame fetching works out of the box:

1. When a new error is logged with a backtrace, a background job is automatically enqueued
2. The job fetches git blame information asynchronously
3. Blame information appears in the dashboard within seconds of the error occurring
4. If blame information can't be fetched (e.g., git not available), the error is logged but the application continues normally

You can still manually fetch blame information for existing errors using the `fetch_blame_info` method on an `ErrorLog` instance.

### Configuration

To enable git blame functionality, ensure your application has access to the git repository. By default, the engine uses `Rails.root` as the repository path. You can customize this in your initializer:

```ruby
ButterflyNet.configure do |config|
  # Optional: Path to the git repository (defaults to Rails.root)
  config.repo_path = Rails.root.to_s
end
```

## User Tracking and Error Occurrences

ButterflyNet tracks each occurrence of an error separately, allowing you to:

- See how many times an error has occurred
- Track which users are affected by each error
- View the timeline of error occurrences
- Filter errors by user impact

### How User Information is Captured

The middleware automatically captures user information **if you provide it** through the Rack environment. Without this setup, errors are still tracked but without user context.

### Setting Up User Tracking

Add this code to your `ApplicationController` or a concern to enable user tracking:

```ruby
# In your ApplicationController or a concern
around_action :set_error_tracking_context

private

def set_error_tracking_context
  # Store user info in request.env for error tracking
  # The middleware will read these values when an error occurs
  request.env["error_tracking.user_id"] = current_user&.id
  request.env["error_tracking.user_email"] = current_user&.email
  yield
end
```

**How it works:**
1. Your controller sets `request.env["error_tracking.user_id"]` and `request.env["error_tracking.user_email"]`
2. When an exception occurs, the `ExceptionCatcher` middleware extracts these values
3. The information is stored in the `error_occurrences` table, linked to the error log

**Note:** If you don't set these values, the gem still works normally - it just won't know which user encountered the error.

### Querying Errors by User Impact

The `ErrorLog` model provides scopes for filtering by user:

```ruby
# Find all errors affecting a specific user
ButterflyNet::ErrorLog.affecting_user(user_id)

# Find all errors affecting a specific email
ButterflyNet::ErrorLog.affecting_user_email("user@example.com")

# Find repeated errors (more than one occurrence)
ButterflyNet::ErrorLog.repeated

# Get occurrence count and affected users for an error
error_log = ButterflyNet::ErrorLog.find(123)
error_log.occurrence_count       # => 42
error_log.affected_users_count   # => 15
```

## Error Status Management

Each error can be tracked through its lifecycle with status values:

- **open** (default): Error is newly discovered and needs attention
- **in_progress**: Someone is actively working on fixing the error
- **resolved**: Error has been fixed
- **dismissed**: Error is intentionally being ignored

### Using Status Scopes

```ruby
# Filter errors by status
ButterflyNet::ErrorLog.open
ButterflyNet::ErrorLog.resolved
ButterflyNet::ErrorLog.with_status("in_progress")

# Update error status
error_log = ButterflyNet::ErrorLog.find(123)
error_log.update(status: "resolved")
```

## GitHub Issue Integration

ButterflyNet can create GitHub issues directly from the error dashboard using the [Octokit](https://github.com/octokit/octokit.rb) gem.

### Configuration

Add the following to an initializer (e.g., `config/initializers/butterfly_net.rb`):

```ruby
ButterflyNet.configure do |config|
  # Required: GitHub personal access token with repo scope
  config.github_access_token = ENV["GITHUB_TOKEN"]
  
  # Required: Repository owner (organization or username)
  config.github_repo_owner = "your-org"
  
  # Required: Repository name
  config.github_repo_name = "your-app"
  
  # Optional: Path to the git repository (defaults to Rails.root)
  config.repo_path = Rails.root.to_s
end
```

### Creating a GitHub Token

1. Go to [GitHub Settings > Developer settings > Personal access tokens](https://github.com/settings/tokens)
2. Generate a new token with the `repo` scope
3. Store the token securely (e.g., as an environment variable)

### Features

When creating a GitHub issue from an error:

- The issue title includes the exception class and message
- The issue body includes:
  - Error details (exception class, timestamp, error ID)
  - Git blame information (if available)
  - Request details (path, method, user agent)
  - Stack trace (collapsed for readability)
- Issues are automatically labeled with `bug` and `error-tracking`

## Styling with Tailwind CSS

ButterflyNet uses [Tailwind CSS v4](https://tailwindcss.com/) for styling via the [tailwindcss-ruby](https://github.com/rails/tailwindcss-ruby) gem. The styles are pre-compiled and included in the gem, so you don't need to configure anything for normal use.

### For Gem Developers

If you're contributing to this gem and need to modify the styles:

#### Building CSS

The gem includes rake tasks for building Tailwind CSS:

```bash
# Build CSS (minified)
bundle exec rake app:butterfly_net:tailwindcss:build

# Watch mode for development
bundle exec rake app:butterfly_net:tailwindcss:watch
```

#### Source Files

- **Input**: `app/assets/stylesheets/butterfly_net/tailwind.css` - Tailwind directives and source configuration
- **Output**: `app/assets/stylesheets/butterfly_net/application.css` - Compiled CSS (committed to the repo)

#### Tailwind Configuration

Tailwind CSS v4 uses CSS-based configuration. The source paths are configured in `tailwind.css`:

```css
@import "tailwindcss";

@source "../../../views/butterfly_net/**/*.html.erb";
@source "../../../helpers/butterfly_net/**/*.rb";
@source "../../../controllers/butterfly_net/**/*.rb";
```

### Style Isolation

The dashboard uses standard Tailwind utility classes. The styles are loaded via the engine's layout file and are scoped to the engine's views only. This means:

- ButterflyNet styles won't interfere with your host application's styles
- Your application's Tailwind setup (if any) operates independently
- The engine uses its own compiled CSS bundle

### Host Application Considerations

No configuration is needed in your host application. The gem's stylesheet is automatically served via Propshaft when you mount the engine. The stylesheet is referenced using `stylesheet_link_tag "butterfly_net/application"` in the engine's layout.

## Terminal Command

This engine was generated with:

```bash
rails plugin new butterfly_net --mountable
```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).