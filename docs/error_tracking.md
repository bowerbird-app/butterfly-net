# Error Tracking Documentation

This document explains how error tracking works in `ButterflyNet`, specifically focusing on the `ErrorLog` and `ErrorOccurrence` models.

## Overview

The error tracking system is designed to capture exceptions, group them by type, and track individual occurrences. This allows for better analysis of error frequency, user impact, and resolution status.

## Models

### ErrorLog

`ButterflyNet::ErrorLog` is the primary model for storing captured exception data. Each record represents a unique exception type (defined by `exception_class` and `message`) that was caught during requests.

**Key Features:**

*   **Grouping:** Errors are grouped by exception class and message.
*   **Status Management:** Supports statuses: `open`, `in_progress`, `resolved`, `dismissed`.
    *   Automatically sets `resolved_at` timestamp when status changes to `resolved`.
*   **Git Integration:**
    *   Automatically fetches git blame information in the background (`FetchBlameJob`) upon creation if a backtrace is present.
    *   Stores blame details: file, line number, commit SHA, author, etc.
*   **GitHub Integration:**
    *   Can create GitHub issues directly from the error log.
    *   Tracks associated GitHub issue numbers and URLs.
*   **Scopes:**
    *   `recent`: Orders by creation date.
    *   `open`, `resolved`: Filters by status.
    *   `repeated`: Finds errors with more than one occurrence.
    *   `affecting_user(user_id)`: Finds errors that have affected a specific user.

**Important Methods:**

*   `find_or_create_with_occurrence`: Main entry point. Finds an existing log or creates a new one, then records a new occurrence.
*   `record_occurrence`: Adds a new occurrence record to the log.
*   `fetch_blame_info`: Retrieves git blame data from the backtrace.
*   `create_github_issue`: Creates a linked GitHub issue.

### ErrorOccurrence

`ButterflyNet::ErrorOccurrence` tracks individual instances of an error. It belongs to an `ErrorLog`.

**Key Features:**

*   **User Tracking:** Captures `user_id` and `user_email` to identify who was affected.
*   **Context:** Stores `request_params` and `user_agent` for debugging context.
*   **Timing:** Timestamps allow for analyzing error frequency over time.

**Scopes:**

*   `recent`: Orders by creation date.
*   `for_user(user_id)`: Filters occurrences for a specific user ID.
*   `for_user_email(email)`: Filters occurrences for a specific email.

## Usage Example

When an exception is caught (e.g., in middleware), the system typically does the following:

```ruby
ButterflyNet::ErrorLog.find_or_create_with_occurrence(
  exception_class: exception.class.name,
  message: exception.message,
  backtrace: exception.backtrace.join("\n"),
  user_id: current_user&.id,
  user_email: current_user&.email,
  request_params: params.to_unsafe_h,
  user_agent: request.user_agent
)
```

This ensures that if the error is new, a log is created and blame info is fetched. If it's a known error, it simply logs another occurrence.
