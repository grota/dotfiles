# glab API Patterns Reference

This file covers common `glab api` patterns for operations that go beyond the built-in subcommands.

## Table of Contents

1. [Authentication and basics](#authentication-and-basics)
2. [Project information](#project-information)
3. [Repository files](#repository-files)
4. [Issues (advanced)](#issues-advanced)
5. [Merge requests (advanced)](#merge-requests-advanced)
6. [Users and members](#users-and-members)
7. [Labels and milestones](#labels-and-milestones)
8. [GraphQL queries](#graphql-queries)

---

## Authentication and basics

`glab api` inherits authentication from `glab auth`. When inside a git repo, it auto-detects the GitLab instance and project.

```bash
# Test connectivity
glab api projects/:id

# Get current user
glab api user
```

### HTTP methods

```bash
glab api PATH                        # GET (default)
glab api -X POST PATH -f key=value   # POST with form fields
glab api -X PUT PATH -f key=value    # PUT
glab api -X DELETE PATH              # DELETE
```

### Passing data

- `-f key=value` -- string field
- `-F key=value` -- typed field (numbers, booleans without quotes)
- `-F key=@file.json` -- read value from file as string (NOT multipart -- see "File uploads" in SKILL.md for binary files)
- `--input file.json` -- send file as request body

### Pagination

```bash
# Auto-paginate all results
glab api projects/:id/issues --paginate

# Manual pagination
glab api "projects/:id/issues?per_page=100&page=2"
```

---

## Project information

```bash
# Get project details
glab api projects/:id

# List project members
glab api projects/:id/members/all

# Get project variables (CI/CD)
glab api projects/:id/variables

# List project branches
glab api projects/:id/repository/branches

# Get default branch
glab api projects/:id | jq '.default_branch'

# List project hooks/webhooks
glab api projects/:id/hooks
```

---

## Repository files

```bash
# Get raw file content (plain text output)
glab api "projects/:id/repository/files/.gitlab-ci.yml/raw?ref=main"

# Get raw file from a subdirectory (URL-encode slashes as %2F)
glab api "projects/:id/repository/files/src%2Fconfig%2Fapp.yml/raw?ref=develop"

# Get file metadata (returns JSON with base64-encoded content)
glab api "projects/:id/repository/files/.gitlab-ci.yml?ref=main"
# Decode the content: ... | jq -r '.content' | base64 -d

# List files in a directory
glab api "projects/:id/repository/tree?ref=main&path=deploy"

# Recursive directory listing
glab api "projects/:id/repository/tree?ref=main&recursive=true&per_page=100" --paginate

# List files with details (name, type, path)
glab api "projects/:id/repository/tree?ref=main&path=src" | jq '.[] | {name, type, path}'

# Get file from another project (URL-encode the project path too)
GITLAB_HOST=gitlab.example.com glab api \
  "projects/team%2Fother-project/repository/files/docker-compose.yml/raw?ref=main"

# Compare files across branches using the compare API
glab api "projects/:id/repository/compare?from=main&to=develop"
```

### File path encoding

File paths with slashes must be URL-encoded (`/` → `%2F`). The project path in the URL must also be encoded when not using the `:id` placeholder:

| What | Raw | Encoded |
|------|-----|---------|
| File path | `src/config/app.yml` | `src%2Fconfig%2Fapp.yml` |
| Project path | `team/infra/platform` | `team%2Finfra%2Fplatform` |

---

## Issues (advanced)

```bash
# Get issue details with full metadata
glab api projects/:id/issues/42

# List issue comments/notes
glab api projects/:id/issues/42/notes

# Add a note with special formatting
glab api -X POST projects/:id/issues/42/notes \
  -f body="## Summary\nThe fix has been deployed to staging."

# Create a confidential issue
glab api -X POST projects/:id/issues \
  -f title="Security vulnerability in auth" \
  -f description="Details..." \
  -F confidential=true

# Set issue weight (GitLab Premium)
glab api -X PUT projects/:id/issues/42 -F weight=5

# List related issues
glab api projects/:id/issues/42/related_merge_requests

# Subscribe/unsubscribe to issue notifications
glab api -X POST projects/:id/issues/42/subscribe
glab api -X POST projects/:id/issues/42/unsubscribe

# Set time estimate
glab api -X POST projects/:id/issues/42/time_estimate -f duration="3h"

# Log time spent
glab api -X POST projects/:id/issues/42/add_spent_time -f duration="1h30m"
```

---

## Merge requests (advanced)

```bash
# Get MR details with full metadata
glab api projects/:id/merge_requests/15

# List MR comments/discussions
glab api projects/:id/merge_requests/15/notes

# List MR changes (file-level diff summary)
glab api projects/:id/merge_requests/15/changes

# Get MR approvals status
glab api projects/:id/merge_requests/15/approvals

# Get MR approval rules
glab api projects/:id/merge_requests/15/approval_rules

# List commits in an MR
glab api projects/:id/merge_requests/15/commits

# Create a thread on a specific line of code
glab api -X POST projects/:id/merge_requests/15/discussions \
  -f body="This null check should handle the empty string case too." \
  -f "position[base_sha]=abc123" \
  -f "position[head_sha]=def456" \
  -f "position[start_sha]=abc123" \
  -f "position[position_type]=text" \
  -f "position[new_path]=src/auth.py" \
  -f "position[new_line]=42"

# Check merge status / conflicts
glab api projects/:id/merge_requests/15 | jq '{merge_status: .merge_status, has_conflicts: .has_conflicts}'

# List MR pipelines
glab api projects/:id/merge_requests/15/pipelines
```

---

## Users and members

```bash
# Search for a user by username
glab api "users?username=jdoe"

# List project members with access levels
glab api projects/:id/members/all | jq '.[] | {username: .username, access_level: .access_level}'

# Access levels: 10=Guest, 20=Reporter, 30=Developer, 40=Maintainer, 50=Owner
```

---

## Labels and milestones

```bash
# List all project labels
glab api projects/:id/labels

# Create a scoped label
glab api -X POST projects/:id/labels \
  -f name="priority::critical" \
  -f color="#FF0000"

# List milestones
glab api projects/:id/milestones

# Get issues in a milestone
glab api "projects/:id/milestones/3/issues"
```

---

## GraphQL queries

For complex queries that need data from multiple resources at once, use GraphQL:

```bash
# Basic GraphQL query
glab api graphql -f query='
  query {
    project(fullPath: "mygroup/myproject") {
      name
      description
      mergeRequests(state: opened, first: 10) {
        nodes {
          iid
          title
          author { username }
          approvedBy { nodes { username } }
        }
      }
    }
  }
'

# GraphQL with variables
glab api graphql -f query='
  query($path: ID!) {
    project(fullPath: $path) {
      issues(state: opened, search: "login") {
        nodes {
          iid
          title
          labels { nodes { title } }
        }
      }
    }
  }
' -f variables='{"path": "mygroup/myproject"}'
```

### Paginated GraphQL

Use `$endCursor` for pagination:

```bash
glab api graphql --paginate -f query='
  query($endCursor: String) {
    project(fullPath: "mygroup/myproject") {
      issues(after: $endCursor, first: 100) {
        pageInfo { hasNextPage endCursor }
        nodes { iid title }
      }
    }
  }
'
```

The `--paginate` flag with `$endCursor` automatically fetches all pages.
