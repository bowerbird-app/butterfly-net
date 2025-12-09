# Testing and Coverage

## Overview

This gem uses Minitest as the testing framework. Code coverage is tracked using SimpleCov when the `COVERAGE` environment variable is set.

## Running Tests

### Without Coverage
```bash
bundle exec rake app:test
```

### With Coverage
```bash
COVERAGE=true bundle exec rake app:test
```

Coverage reports are generated in the `coverage/` directory. Open `coverage/index.html` in a browser to view the full report.

### Running Individual Tests
```bash
# Without coverage
bundle exec ruby -Itest test/path/to/test_file.rb

# With coverage
COVERAGE=true bundle exec ruby -Itest test/path/to/test_file.rb
```

## SimpleCov Configuration

### Problem We Solved

SimpleCov must start **before** any application code is loaded, otherwise it cannot track code coverage for files that are loaded before SimpleCov initializes.

In a Rails engine, there are two code loading paths:
1. **Via Rake tasks** (`rake app:test`): The Rakefile loads Rails engine tasks, which loads the dummy app's Rakefile, which loads `config/application.rb`, which initializes Rails and loads the gem files.
2. **Via direct test execution** (`ruby -Itest test/file.rb`): The test file requires `test_helper.rb`, which loads the Rails environment and gem files.

### Solution

We start SimpleCov in **both** locations to ensure coverage tracking begins before code loading, regardless of how tests are run:

1. **Rakefile**: SimpleCov starts before loading `rails/tasks/engine.rake`
   - Handles coverage when running tests via rake tasks
   - Ensures gem files are tracked even when Rails initializes them

2. **test/test_helper.rb**: SimpleCov starts before loading the Rails environment
   - Handles coverage when running tests directly
   - SimpleCov is idempotent, so calling `start` twice is safe

### Using require_relative Instead of Autoloading

The test_helper explicitly requires the main gem file using `require_relative` after Rails loads:

```ruby
require_relative "../lib/marco_butterfly_net"
```

The main gem file (`lib/marco_butterfly_net.rb`) then requires all its dependencies:
- `marco_butterfly_net/version`
- `marco_butterfly_net/engine`
- `marco_butterfly_net/configuration`
- `marco_butterfly_net/middleware/exception_catcher`
- `marco_butterfly_net/services/git_blame`
- `marco_butterfly_net/services/github_issue_creator`
- `marco_butterfly_net/services/analytics`

This ensures:
- Consistent code loading behavior
- Better coverage tracking (SimpleCov can hook into `require_relative`)
- Files are loaded even if they aren't autoloaded during tests
- No reliance on Rails autoloading behavior in tests
- Proper dependency order (main file requires its dependencies)

## Verification

To verify SimpleCov is tracking lib files correctly:

```bash
COVERAGE=true bundle exec rake app:test
```

Check the coverage report - all files in `lib/marco_butterfly_net/` should show coverage percentages > 0% (except version.rb which only contains a constant).

Expected output:
```
Coverage report generated for Minitest to .../coverage.
Line Coverage: ~35-40% (varies as code evolves)
```

If lib files show 0% coverage, SimpleCov is starting too late.
