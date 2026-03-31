# gh API Patterns Reference

This file covers common `gh api` patterns for operations that go beyond the built-in subcommands.

## Table of Contents

1. [Authentication and basics](#authentication-and-basics)
2. [Repository information](#repository-information)
3. [Issues (advanced)](#issues-advanced)
4. [Pull requests (advanced)](#pull-requests-advanced)
5. [Review comments and threads](#review-comments-and-threads)
6. [Users and teams](#users-and-teams)
7. [Labels and milestones](#labels-and-milestones)
8. [GraphQL queries](#graphql-queries)

---

## Authentication and basics

`gh api` inherits authentication from `gh auth`. When inside a git repo, it auto-detects the GitHub instance and repository.

```bash
# Test connectivity
gh api repos/{owner}/{repo}

# Get current user
gh api user --jq '.login'
```

### HTTP methods

```bash
gh api PATH                              # GET (default)
gh api -X POST PATH -f key=value         # POST with string fields
gh api -X PATCH PATH -f key=value        # PATCH
gh api -X PUT PATH -f key=value          # PUT
gh api -X DELETE PATH                    # DELETE
```

### Passing data

- `-f key=value` -- string field (always treated as a string)
- `-F key=value` -- typed field (numbers, booleans without quotes; `true`, `false`, `null`, integers auto-convert)
- `-F key=@file.json` -- read value from file
- `--input file.json` -- send file as the entire request body

### Pagination

```bash
# Auto-paginate all results
gh api repos/{owner}/{repo}/issues --paginate

# Paginate and collect into a single JSON array
gh api repos/{owner}/{repo}/issues --paginate --slurp

# Manual pagination
gh api "repos/{owner}/{repo}/issues?per_page=100&page=2"
```

### The `--jq` flag

`gh api` has native `--jq` support -- no need to pipe to external `jq`:

```bash
# Extract a single field
gh api user --jq '.login'

# Filter arrays
gh api repos/{owner}/{repo}/issues --jq '.[] | select(.labels | length > 0) | {number, title}'

# Tabular output
gh api repos/{owner}/{repo}/contributors --jq '.[] | [.login, .contributions] | @tsv'

# Combine with --paginate
gh api repos/{owner}/{repo}/issues --paginate --jq '.[].title'
```

---

## Repository information

```bash
# Get repository details
gh api repos/{owner}/{repo}

# Get default branch
gh api repos/{owner}/{repo} --jq '.default_branch'

# List collaborators
gh api repos/{owner}/{repo}/collaborators --jq '.[] | {login: .login, role: .role_name}'

# Get branch protection rules
gh api repos/{owner}/{repo}/branches/main/protection

# List repository topics
gh api repos/{owner}/{repo}/topics --jq '.names'

# List webhooks
gh api repos/{owner}/{repo}/hooks
```

---

## Issues (advanced)

```bash
# Get issue details with full metadata
gh api repos/{owner}/{repo}/issues/42

# List issue comments (timeline comments)
gh api repos/{owner}/{repo}/issues/42/comments

# Add a comment with formatting
gh api -X POST repos/{owner}/{repo}/issues/42/comments \
  -f body="## Summary\nThe fix has been deployed to staging."

# List issue events (label changes, assignments, etc.)
gh api repos/{owner}/{repo}/issues/42/events

# List issue timeline (comprehensive event history)
gh api repos/{owner}/{repo}/issues/42/timeline

# Lock an issue conversation
gh api -X PUT repos/{owner}/{repo}/issues/42/lock \
  -f lock_reason="resolved"

# Set issue as discussion (convert)
gh api -X PATCH repos/{owner}/{repo}/issues/42 \
  -f state="closed" -f state_reason="not_planned"
```

---

## Pull requests (advanced)

```bash
# Get PR details with full metadata
gh api repos/{owner}/{repo}/pulls/15

# List PR files (changed files summary)
gh api repos/{owner}/{repo}/pulls/15/files --jq '.[] | {filename, status, additions, deletions}'

# List commits in a PR
gh api repos/{owner}/{repo}/pulls/15/commits --jq '.[] | {sha: .sha[0:7], message: .commit.message}'

# Check merge status and conflicts
gh api repos/{owner}/{repo}/pulls/15 --jq '{mergeable, mergeable_state, merge_commit_sha}'

# List PR reviews
gh api repos/{owner}/{repo}/pulls/15/reviews --jq '.[] | {id, user: .user.login, state, body}'

# Get a specific review's comments
gh api repos/{owner}/{repo}/pulls/15/reviews/<review_id>/comments

# List requested reviewers
gh api repos/{owner}/{repo}/pulls/15/requested_reviewers --jq '{users: [.users[].login], teams: [.teams[].slug]}'

# List PR pipelines / check runs
gh api repos/{owner}/{repo}/commits/<sha>/check-runs --jq '.check_runs[] | {name, status, conclusion}'
```

---

## Review comments and threads

This is the most common reason to use `gh api` for PRs -- the CLI has no subcommands for inline code comments.

```bash
# List all review comments on a PR
gh api repos/{owner}/{repo}/pulls/15/comments \
  --jq '.[] | {id, in_reply_to_id, user: .user.login, path, line, body: (.body | .[0:80])}'

# Reply to a review comment (by comment ID)
gh api -X POST repos/{owner}/{repo}/pulls/15/comments/<comment_id>/replies \
  -f body="Good point -- I'll fix this."

# Alternative: reply using in_reply_to parameter
gh api -X POST repos/{owner}/{repo}/pulls/15/comments \
  -f body="Agreed." \
  -F in_reply_to=<comment_id>

# Create a new inline comment on a specific line
COMMIT_SHA=$(gh pr view 15 --json headRefOid --jq '.headRefOid')
gh api -X POST repos/{owner}/{repo}/pulls/15/comments \
  -f body="Consider adding error handling here." \
  -f commit_id="$COMMIT_SHA" \
  -f path="src/auth.ts" \
  -F line=42 \
  -f side="RIGHT"

# Create a multi-line review comment
gh api -X POST repos/{owner}/{repo}/pulls/15/comments \
  -f body="This whole block should be extracted into a helper." \
  -f commit_id="$COMMIT_SHA" \
  -f path="src/auth.ts" \
  -F start_line=30 \
  -f start_side="RIGHT" \
  -F line=45 \
  -f side="RIGHT"

# Edit a review comment
gh api -X PATCH repos/{owner}/{repo}/pulls/comments/<comment_id> \
  -f body="Updated comment text."

# Delete a review comment
gh api -X DELETE repos/{owner}/{repo}/pulls/comments/<comment_id>

# Edit a PR timeline comment (issue-style comment)
gh api -X PATCH repos/{owner}/{repo}/issues/comments/<comment_id> \
  -f body="Updated timeline comment."
```

---

## Users and teams

```bash
# Search for a user by username
gh api "users/jdoe"

# List organization members
gh api orgs/<org>/members --jq '.[] | .login'

# List team members
gh api orgs/<org>/teams/<team-slug>/members --jq '.[] | .login'

# Check if user is a collaborator
gh api repos/{owner}/{repo}/collaborators/<username> --silent && echo "yes" || echo "no"
```

---

## Labels and milestones

```bash
# List all labels (with colors and descriptions)
gh api repos/{owner}/{repo}/labels --jq '.[] | {name, color, description}'

# Create a label
gh api -X POST repos/{owner}/{repo}/labels \
  -f name="priority:critical" \
  -f color="FF0000" \
  -f description="Critical priority issue"

# List milestones
gh api repos/{owner}/{repo}/milestones --jq '.[] | {number, title, state, due_on}'

# Get issues in a milestone
gh api "repos/{owner}/{repo}/issues?milestone=3&state=all" --jq '.[] | {number, title, state}'
```

---

## GraphQL queries

For complex queries that need data from multiple resources at once, use GraphQL:

```bash
# Basic GraphQL query
gh api graphql -f query='
  query {
    repository(owner: "myorg", name: "myrepo") {
      name
      description
      pullRequests(states: OPEN, first: 10) {
        nodes {
          number
          title
          author { login }
          reviewDecision
          commits(last: 1) {
            nodes {
              commit {
                statusCheckRollup {
                  state
                }
              }
            }
          }
        }
      }
    }
  }
'

# GraphQL with variables
gh api graphql -f query='
  query($owner: String!, $name: String!, $search: String!) {
    repository(owner: $owner, name: $name) {
      issues(filterBy: {states: OPEN}, first: 20, orderBy: {field: UPDATED_AT, direction: DESC}) {
        nodes {
          number
          title
          labels(first: 5) { nodes { name } }
        }
      }
    }
  }
' -f owner="myorg" -f name="myrepo" -f search="login"
```

### Paginated GraphQL

Use `$endCursor` with `--paginate` for automatic pagination:

```bash
gh api graphql --paginate -f query='
  query($endCursor: String) {
    repository(owner: "myorg", name: "myrepo") {
      issues(first: 100, after: $endCursor) {
        pageInfo { hasNextPage endCursor }
        nodes { number title }
      }
    }
  }
'
```

The `--paginate` flag with `$endCursor` automatically fetches all pages. Add `--slurp` to merge all pages into a single JSON array.
