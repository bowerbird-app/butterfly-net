# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.5.0] - 2026-03-26

### Added
- **FlatPack UI Integration**: Dashboard now uses the `flat_pack` component library for a consistent, modern UI
  - Sidebar navigation layout with Errors and Analytics links (`FlatPack::SidebarLayout`)
  - `FlatPack::PageHeader::Component` for page titles across all dashboard views
  - `FlatPack::Card::Component` for error detail and analytics chart cards
  - `FlatPack::Table::Component` for the errors index table with built-in empty state
  - `FlatPack::Badge::Component` for colour-coded status badges
  - `FlatPack::Button::Component` for action buttons
  - `FlatPack::Alert::Component` for flash notice/alert messages
  - `FlatPack::Link::Component` for external GitHub issue URLs
  - `FlatPack::Breadcrumb::Component` replacing the back button on the show page
  - `FlatPack::Grid::Component` for responsive analytics metric grids
  - Adds `flat_pack`, `importmap-rails`, `turbo-rails`, and `stimulus-rails` as gem dependencies

- **Enriched GitHub Issue Body**: Issues created from the dashboard now include significantly more context
  - Ruby, Rails, and ButterflyNet version information
  - Occurrence count in the error details table
  - Link back to the error in the dashboard when `dashboard_host` is configured
  - Code context with ±5 surrounding lines and the blamed line highlighted (`→`)
  - Request parameters (filtered) as pretty-printed JSON
  - New `dashboard_host` configuration option for generating dashboard links in issues

- **Automatic Git Blame Fetching**: Blame is now fetched reliably in the background when errors are created
  - Blame fetch failures are caught and logged as non-fatal — errors are still recorded even if blame is unavailable
  - Removed `retry_on StandardError` from `FetchBlameJob` (it conflicted with the internal rescue block, preventing retries from ever triggering)
  - Show page displays a fallback manual "Fetch Git Blame" button with a note that auto-fetch was already attempted

- **Upstream Bowerbird Reporting**: File issues directly in upstream `bowerbird-app` dependency gem repositories
  - New `bowerbird_gem_repos` config: maps bundler gem names to GitHub repo names under `bowerbird_org`
  - New `bowerbird_org` config: GitHub organisation for bowerbird-app gems (defaults to `"bowerbird-app"`)
  - `ErrorLog#bowerbird_repos_from_backtrace` detects bowerbird gems in a backtrace
  - `ErrorLog#create_github_issue` accepts a `target_repo:` parameter to file in a specific repo
  - "Report to [gem]" buttons shown on the error show page when bowerbird gems are detected
  - `DashboardController` validates `target_repo` against an allowlist before creating issues

- **GitHub Issue Environment Guard**: Prevent accidental issue creation in development
  - New `github_issue_environments` config (defaults to `%w[production staging]`)
  - Issue creation buttons are hidden and the API is blocked in environments not on the list
  - `github_configured?` now factors in the current Rails environment

### Changed
- Dashboard layout replaced with `FlatPack::SidebarLayout`; the "View Analytics" button has been removed from the index page header (analytics is now always accessible via the sidebar)
- `FetchBlameJob` no longer uses `retry_on StandardError`; failures are handled internally and logged

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
bin/rails butterfly_net:install:migrations
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

[Unreleased]: https://github.com/bowerbird-app/marco-butterfly-net/compare/v0.5.0...HEAD
[0.5.0]: https://github.com/bowerbird-app/marco-butterfly-net/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/bowerbird-app/marco-butterfly-net/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/bowerbird-app/marco-butterfly-net/releases/tag/v0.3.0
