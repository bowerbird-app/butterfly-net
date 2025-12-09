# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.4.0] - 2025-12-09

### Added
- **User Tracking**: Track which users are affected by each error
  - New `error_occurrences` table to record individual error instances
  - Separate user information (`user_id`, `user_email`) for each occurrence
  - Request parameters and user agent tracked per occurrence
  - Ability to filter errors by affected users
  - Scopes: `affecting_user`, `affecting_user_email`, `repeated`
  - Methods: `occurrence_count`, `affected_users_count`

- **Error Status Management**: Track bug resolution lifecycle
  - Status field on error_logs with values: `open`, `in_progress`, `resolved`, `dismissed`
  - Default status is `open` for new errors
  - Scopes: `with_status`, `open`, `resolved`
  - Proper validation of status values

- **Improved Error Grouping**: Identical errors are now grouped together
  - Same error type (class + message) creates one `ErrorLog` record
  - Each occurrence is tracked separately in `ErrorOccurrence` records
  - View complete history of when errors occurred and who was affected

### Changed
- `ErrorLog` model now uses `has_many :occurrences` relationship
- Request parameters and user agent moved from `ErrorLog` to `ErrorOccurrence`
- Migration adds foreign key constraint from occurrences to error_logs
- Indexes added for efficient querying by user_id, user_email, status, and created_at

### Migration Guide

After updating to this version, run the new migration:

```bash
bin/rails marco_butterfly_net:install:migrations
bin/rails db:migrate
```

This will:
1. Add the `status` column to existing error_logs (defaults to "open")
2. Create the new `error_occurrences` table
3. Add necessary indexes for performance

**Note**: Existing error_logs will not have occurrence records. New errors after the migration will properly track occurrences.

## [0.3.0] - 2024-12-02

### Added
- Git blame integration to identify code authors
- GitHub issue creation from error dashboard
- Comprehensive test coverage for all features

### Features
- Mountable Rails engine for error tracking
- Rack middleware to catch exceptions
- Database persistence with namespaced tables
- Clean dashboard UI
- Git blame analysis
- GitHub issue integration via Octokit

## Earlier Versions

See git history for changes in versions prior to 0.3.0.

[Unreleased]: https://github.com/bowerbird-app/marco-butterfly-net/compare/v0.4.0...HEAD
[0.4.0]: https://github.com/bowerbird-app/marco-butterfly-net/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/bowerbird-app/marco-butterfly-net/releases/tag/v0.3.0
