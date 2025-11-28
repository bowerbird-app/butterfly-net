# MarcoButterflyNet

MarcoButterflyNet is a self-hosted error tracking dashboard for Rails applications. It's built as a mountable Rails engine that uses Rack middleware to intercept exceptions from the entire Rails stack.

## Features

- **Mountable Engine**: Mount it at any path in your Rails application
- **Namespace Isolation**: Uses `isolate_namespace` for clean separation
- **Rack Middleware**: Catches exceptions from the entire stack, not just controller errors
- **Persistent Storage**: Stores errors in a database table (namespaced to avoid conflicts)
- **Dashboard UI**: Clean, paginated interface to browse and inspect errors
- **Scoped Styling**: CSS is namespaced to avoid conflicts with host application styles

## Installation

Add this line to your application's Gemfile:

```ruby
gem "marco_butterfly_net"
```

And then execute:

```bash
bundle install
```

Run the migration to create the error logs table:

```bash
bin/rails marco_butterfly_net:install:migrations
bin/rails db:migrate
```

## Usage

### Basic Setup

Mount the engine in your `config/routes.rb`:

```ruby
Rails.application.routes.draw do
  mount MarcoButterflyNet::Engine, at: "/errors"
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
    mount MarcoButterflyNet::Engine, at: "/errors"
  end
end
```

### Securing with HTTP Basic Auth

For simple protection, you can use HTTP Basic Auth:

```ruby
Rails.application.routes.draw do
  mount MarcoButterflyNet::Engine, at: "/errors", constraints: ->(request) {
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
    mount MarcoButterflyNet::Engine, at: "/errors"
  end
end
```

### Restricting to Internal Networks

For additional security, restrict access to internal networks:

```ruby
Rails.application.routes.draw do
  constraints ->(request) { ['127.0.0.1', '::1'].include?(request.remote_ip) } do
    mount MarcoButterflyNet::Engine, at: "/errors"
  end
end
```

## Data Model

The engine creates a `marco_butterfly_net_error_logs` table with the following fields:

| Field | Type | Description |
|-------|------|-------------|
| `exception_class` | string | The class name of the exception (e.g., `NoMethodError`) |
| `message` | text | The exception message |
| `backtrace` | text | The full stack trace |
| `request_params` | json | Request details (path, method, query string, params) |
| `user_agent` | string | The client's User-Agent header |
| `created_at` | datetime | When the error occurred |

## Architecture

### Mountable Engine

MarcoButterflyNet is built as a mountable Rails engine using `--mountable`, providing:
- Isolated routes scoped under a mount point
- Namespaced controllers, models, and views
- Separate asset pipeline

### Namespace Isolation

The engine uses `isolate_namespace MarcoButterflyNet` to prevent naming conflicts with the host application's code.

### Exception Catching

MarcoButterflyNet catches exceptions through two complementary mechanisms:

#### 1. Rack Middleware

The `MarcoButterflyNet::Middleware::ExceptionCatcher` is inserted at the top of the middleware stack to intercept exceptions that propagate up:

```ruby
# Automatically configured by the engine
app.middleware.insert_before(0, MarcoButterflyNet::Middleware::ExceptionCatcher)
```

#### 2. DebugExceptions Interceptor

Rails' `ActionDispatch::DebugExceptions` middleware renders error pages without re-raising exceptions. To capture these errors (like `NameError`, `NoMethodError`, etc.), we register an interceptor:

```ruby
# Automatically configured by the engine
ActionDispatch::DebugExceptions.register_interceptor do |request, exception|
  MarcoButterflyNet::Middleware::ExceptionCatcher.handle_intercepted_exception(exception, request.env)
end
```

Together, these mechanisms ensure all exceptions are caught from the entire request/response cycle, including:
- Controller errors (e.g., `NameError`, `NoMethodError`)
- Model/ActiveRecord errors
- View/template errors
- Routing errors
- Other middleware errors

## Terminal Command

This engine was generated with:

```bash
rails plugin new marco_butterfly_net --mountable
```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).