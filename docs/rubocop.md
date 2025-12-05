# RuboCop Setup and Usage

This project uses [RuboCop](https://rubocop.org/) for static code analysis and formatting, specifically following the [Omakase Ruby styling](https://github.com/rails/rubocop-rails-omakase).

## Configuration

The RuboCop configuration is located in `.rubocop.yml` in the root directory. It inherits from `rubocop-rails-omakase`.

## Running RuboCop

To check for offenses, run:

```bash
bin/rubocop
```

## Autocorrecting Offenses

To automatically fix offenses that can be corrected, run:

```bash
bin/rubocop -a
```

or for more aggressive autocorrection:

```bash
bin/rubocop -A
```

## Integration

RuboCop is included in the `Gemfile` and should be installed via `bundle install`.

## VS Code Integration

This project is configured to use the `misogi.ruby-rubocop` extension and `Shopify.ruby-lsp` in the dev container.
Settings are pre-configured to enable RuboCop linting and formatting on save.

## CI Integration

RuboCop checks are automatically run as part of the Continuous Integration (CI) workflow defined in `.github/workflows/ci.yml`.
Any pull request or push to the repository will trigger these checks, ensuring code quality standards are maintained.
