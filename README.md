# MarcoButterflyNet

MarcoButterflyNet is a self-hosted error tracking dashboard for Rails applications. It's built as a mountable Rails engine that uses Rack middleware to intercept exceptions from the entire Rails stack.

## Features

- **Mountable Engine**: Mount it at any path in your Rails application
- **Namespace Isolation**: Uses `isolate_namespace` for clean separation
- **Rack Middleware**: Catches exceptions from the entire stack, not just controller errors

## Installation

Add this line to your application's Gemfile:

```ruby
gem "marco_butterfly_net"
```

And then execute:

```bash
bundle install
```

## Usage

Mount the engine in your `config/routes.rb`:

```ruby
Rails.application.routes.draw do
  mount MarcoButterflyNet::Engine, at: "/errors"
end
```

The middleware is automatically inserted into your Rails middleware stack when the engine is loaded.

## Architecture

### Mountable Engine

MarcoButterflyNet is built as a mountable Rails engine using `--mountable`, providing:
- Isolated routes scoped under a mount point
- Namespaced controllers, models, and views
- Separate asset pipeline

### Namespace Isolation

The engine uses `isolate_namespace MarcoButterflyNet` to prevent naming conflicts with the host application's code.

### Rack Middleware

The `MarcoButterflyNet::Middleware::ExceptionCatcher` is inserted at the top of the middleware stack to intercept all exceptions:

```ruby
# Automatically configured by the engine
app.middleware.insert_before(0, MarcoButterflyNet::Middleware::ExceptionCatcher)
```

This ensures exceptions are caught from the entire request/response cycle, including:
- Controller errors
- Model/ActiveRecord errors
- View/template errors
- Other middleware errors

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).