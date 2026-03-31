---
name: gh
description: 'How to use the GitHub CLI (gh) to work with GitHub issues, pull requests, Actions workflows, releases, and repositories. Use this skill whenever the user provides a URL containing "github.com" in the hostname, mentions pull requests, GitHub issues, GitHub Actions, or wants to interact with a GitHub remote. Also use this skill when the user mentions "gh", "PR", "pull request", or when you detect the git remote points to a GitHub instance (look for "github" in the remote URL). This skill is the GitHub equivalent of using `glab` for GitLab -- if the project is on GitHub, use this skill instead.'
---

# gh CLI Skill

Use the `gh` CLI for ALL GitHub-related tasks including working with issues, pull requests, Actions workflows, releases, and repositories. If given a GitHub URL, use `gh` to get the information needed.

## Before you start

1. **Detect GitHub URLs**: if the user provided a URL containing "github.com", this is a GitHub resource. Extract the owner and repo from the URL and proceed with `gh` commands using `-R owner/repo`.
2. **Confirm it's a GitHub project**: check `git remote -v` for "github" in the URL. If so, use `gh` (not `glab`).
3. **Verify authentication**: run `gh auth status`. If not authenticated, **stop and ask the user** -- do not proceed.

## CLI-first principle

**Always prefer gh subcommands** (`gh issue list`, `gh pr list`, `gh run list`, etc.) over raw `gh api` calls. The CLI subcommands provide better output formatting, pagination, and are less error-prone. Use `gh api` **only** when no subcommand covers the operation (see the `gh api` section below).

## Targeting a repository

Before running any `gh` command, determine the repository context:

1. **User provided a GitHub URL** (e.g., `https://github.com/owner/repo/issues/42` or `https://github.com/owner/repo/pull/15`):
   Extract the **owner/repo** from the URL, then use `-R`:
   ```bash
   # URL: https://github.com/acme/webapp/pull/15
   # Extracted: acme/webapp
   gh pr view 15 -R acme/webapp
   gh issue list -R acme/webapp --label "bug"
   ```

2. **Inside a git repo with a GitHub remote**: no `-R` needed, `gh` detects the repository from the remote automatically.

3. **No URL provided and not inside a git repo**: **ask the user** for the full GitHub repository URL before proceeding. Do not guess or assume a repository.

## Handling auth errors

If any `gh` command fails with "authentication", "401", "403", or "could not determine", **stop immediately**. Do NOT work around auth failures with WebFetch, curl, or `glab`.

Present the user with these options:

### Option 1: Browser login (preferred -- more secure, tokens auto-refresh)

```bash
gh auth login --web
# Browser opens -> authorize -> done
```

### Option 2: Personal Access Token

Tell the user to generate a token at: `https://github.com/settings/tokens?type=beta` -- recommend fine-grained tokens with minimal scopes and a short expiry (30-90 days).

```bash
gh auth login --with-token < token.txt
```

### Option 3: Skip the operation

## Core terminology

| GitLab | GitHub | CLI |
|--------|--------|-----|
| Merge Request | **Pull Request** | `gh pr` |
| Snippet | **Gist** | `gh gist` |
| CI/CD | **Actions** | `gh run`, `gh workflow` |
| `GROUP/PROJECT` (supports nesting) | `OWNER/REPO` | -- |
| MR `!15` | PR `#15` | -- |

Issues and PRs both use `#` prefix.

---

## Writing on behalf of the user

Whenever you create or post content on GitHub on behalf of the user -- including **PR descriptions** (`gh pr create`), **issue descriptions** (`gh issue create`), **comments** (`gh pr comment`, `gh issue comment`), **reviews** (`gh pr review`), or **`gh api` body fields** -- you **must** prepend the following header to make it clear the content was authored by an AI agent acting on behalf of the user:

```
> :robot: _This was written by an AI agent on behalf of @<username>._
```

Before writing any content, **always fetch the username first** and embed it in the header. Do not hardcode a username or leave the placeholder unfilled:

```bash
# Step 1: fetch the username (do this once per session)
GH_USERNAME=$(gh api user --jq '.login')

# Step 2: use it in the content
gh pr create \
  --title "feat: add dark mode" \
  --body "> :robot: _This was written by an AI agent on behalf of @${GH_USERNAME}._

## Summary

- Adds dark mode toggle to settings page
- ..."
```

**Example** -- adding a comment to issue #42:

```bash
gh issue comment 42 \
  --body "> :robot: _This was written by an AI agent on behalf of @${GH_USERNAME}._

## Triage

Root cause identified: ..."
```

This applies to **every** piece of content the agent creates, regardless of length or context. Never skip the header.

> **Heredoc warning:** when using `cat <<EOF` to build the body, **never** single-quote the delimiter (`<<'EOF'`). Single-quoted heredocs suppress variable expansion and produce the literal string `$GH_USERNAME` instead of the resolved value. Always use an unquoted delimiter:
>
> ```bash
> gh pr create --title "feat: add dark mode" --body "$(cat <<EOF
> > :robot: _This was written by an AI agent on behalf of @${GH_USERNAME}._
>
> ## Summary
>
> - Adds dark mode toggle to settings page
> EOF
> )"
> ```

---

## Issues

```bash
gh issue create --title "Bug: ..." --body "..." --label bug --label "high-priority" --assignee "@me"
gh issue list --assignee @me                      # list my issues
gh issue list --label "bug" --search "login"      # filter and search
gh issue view 42 --comments                       # view with comments
gh issue comment 42 --body "Root cause found."    # add a comment
gh issue edit 42 --add-label "confirmed"          # update metadata
gh issue close 42                                 # close (ask confirmation first)
gh issue reopen 42
```

### Issue template selection

Many GitHub projects define issue templates (stored in `.github/ISSUE_TEMPLATE/`) that encode the team's expected structure -- sections to fill, checklists, labels. Skipping these creates issues that don't match the project's conventions and forces manual cleanup.

Use `--template` to select a template by name:

```bash
# List templates by checking the repository
ls .github/ISSUE_TEMPLATE/
# Or via API
gh api repos/{owner}/{repo}/contents/.github/ISSUE_TEMPLATE --jq '.[].name'

# Create with a template
gh issue create --template "Bug Report" --title "Login crash on empty password"
```

If no `--template` is specified and templates exist, `gh issue create` will prompt interactively. When running non-interactively, check for templates first and ask the user which one to use.

### Label selection process

If the user specified exact labels, use them. Otherwise:

1. **Discover available labels**: `gh label list` (or `gh label list --json name,description` for more detail)
2. **Propose labels that fit** the issue context.
3. **Ask the user to confirm or adjust** before creating the issue.

Do NOT invent label names. Only propose labels that actually exist in the repository.

### Create a branch from an issue

```bash
gh issue develop 42 --checkout              # create branch linked to issue and check it out
gh issue develop 42 --name fix/issue-42     # custom branch name
gh issue develop 42 --base develop          # branch from a specific base
```

---

## Pull Requests

### Creating PRs

```bash
gh pr create --title "Fix login crash" --body "Closes #42" \
  --base develop --reviewer "marco" --assignee "@me"
gh pr create --fill                   # title/description from commits
gh pr create --fill-verbose           # commits msg+body for description
gh pr create --draft --fill           # draft PR
```

Include `Closes #42` or `Fixes #42` in the body to auto-close issues on merge.

### PR title format

PR titles must follow the [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) format:

```
<type>[(optional scope)]: <description>
```

Common types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`.

Use a scope when the change is clearly scoped to a module, component, or area of the codebase. Keep the description lowercase, concise, and in imperative mood.

**Examples:**
```
feat(auth): add JWT token refresh
fix: prevent crash on empty password submission
docs(api): update rate limiting section
refactor(parser): simplify config validation logic
ci: add deploy stage for staging environment
chore: bump dependencies
```

Breaking changes append `!` before the colon: `feat(api)!: change response format for /users endpoint`.

**PR creation checklist** (follow this carefully):

1. **Inspect branch state**: `git status`, `git log <base>...HEAD --oneline`, `git diff <base>...HEAD`
2. **Draft title/description from the actual diff** -- reference specific files, functions, behaviors. Do not just restate the user's request.
3. **Push**: `git push -u origin HEAD` if not yet pushed.
4. **Create**: `gh pr create` with all relevant flags.
5. **Return the PR URL** to the user.

### Reviewing and managing PRs

```bash
gh pr view 15 --comments              # view PR with comments
gh pr diff 15                         # see the diff
gh pr diff 15 --name-only             # list changed files
gh pr list --author @me               # my PRs
gh pr checkout 15                     # checkout locally
gh pr comment 15 --body "LGTM"       # leave a top-level comment
gh pr review 15 --approve --body "Looks good"  # formal approval
gh pr review 15 --request-changes --body "Please fix..." # request changes
gh pr merge 15 --squash --delete-branch
gh pr update-branch 15                # update with latest base branch
gh pr edit 15 --add-label "reviewed"
gh pr ready 15                        # mark draft as ready for review
gh pr ready 15 --undo                 # convert back to draft
gh pr close 15                        # close without merging
```

**Code review workflow**: view PR -> read diff -> check CI (`gh pr checks`) -> read comments -> leave feedback -> approve or request changes.

Approval and comments are separate actions -- `gh pr review --approve` handles GitHub's formal review system, `gh pr comment` posts a timeline comment.

### PR checks (CI status per PR)

```bash
gh pr checks 15                       # one-shot status
gh pr checks 15 --watch               # stream until all checks finish
gh pr checks 15 --watch --interval 5  # custom refresh interval
gh pr checks 15 --required            # only show required checks
gh pr checks 15 --fail-fast           # exit on first failure in watch mode
```

---

## PR Comments and Reviews

GitHub PRs have **three distinct comment types**. Using the wrong one is a common mistake -- a top-level comment when the user wanted a threaded reply to an inline review creates noise and loses context.

### Comment types

| Type | What it is | How to post |
|------|-----------|-------------|
| **Top-level comment** | Timeline comment on the PR (like an issue comment) | `gh pr comment 15 --body "..."` |
| **Review** | Formal review: approve, request changes, or comment with a body | `gh pr review 15 --approve --body "..."` |
| **Inline review comment** | Comment on a specific line of code, starting a thread | `gh api` (no CLI subcommand) |
| **Reply to inline comment** | Threaded reply to an existing inline code comment | `gh api` (no CLI subcommand) |

### Replying to review comments

There is no `gh pr` subcommand for replying to inline code review comments. You must use `gh api`.

**Step 1: List review comments to find the comment ID**

```bash
# List all review comments on PR #15
gh api repos/{owner}/{repo}/pulls/15/comments \
  --jq '.[] | {id, user: .user.login, path, line, body: (.body | .[0:80])}'
```

Each comment has an `id` field. Top-level review comments have no `in_reply_to_id`; replies do.

**Step 2: Reply to a specific comment**

Use the dedicated replies endpoint:

```bash
gh api -X POST repos/{owner}/{repo}/pulls/15/comments/<comment_id>/replies \
  -f body="> :robot: _This was written by an AI agent on behalf of @${GH_USERNAME}._

The null check is needed because..."
```

Constraint: **replies to replies are not supported** by the API -- you can only reply to top-level review comments (those without `in_reply_to_id`). If the comment you want to reply to is itself a reply, reply to the parent comment instead.

**Step 3 (alternative): Reply using `in_reply_to`**

You can also reply via the create comment endpoint with the `in_reply_to` parameter. When `in_reply_to` is set, all other parameters except `body` are ignored:

```bash
gh api -X POST repos/{owner}/{repo}/pulls/15/comments \
  -f body="Agreed, good catch." \
  -F in_reply_to=<comment_id>
```

### Creating a new inline review comment

To start a new thread on a specific line of code:

```bash
# Get the latest commit SHA on the PR
COMMIT_SHA=$(gh pr view 15 --json headRefOid --jq '.headRefOid')

gh api -X POST repos/{owner}/{repo}/pulls/15/comments \
  -f body="This null check should handle empty strings too." \
  -f commit_id="$COMMIT_SHA" \
  -f path="src/auth.ts" \
  -F line=42 \
  -f side="RIGHT"
```

Parameters:
- `commit_id` (required): use the PR's HEAD commit SHA. Using an older commit may render the comment outdated.
- `path` (required): relative file path in the repo.
- `line` (required for line comments): line number in the diff.
- `side`: `RIGHT` for additions (green), `LEFT` for deletions (red).
- `start_line` + `start_side`: for multi-line comments, the first line of the range.

### Responding to all open review comments

When the user asks to respond to review comments on a PR, follow this workflow:

1. **List all review comments**: `gh api repos/{owner}/{repo}/pulls/15/comments --jq '.[] | {id, in_reply_to_id, user: .user.login, path, line, body}'`
2. **Filter to top-level comments** (those without `in_reply_to_id`) that haven't been addressed yet.
3. **Present a summary** to the user: who commented, on which file/line, what they said.
4. **Draft replies** and get user confirmation before posting.
5. **Post replies** using the replies endpoint for each comment.

Never post replies without showing them to the user first.

### Editing and deleting comments

`gh pr comment` and `gh issue comment` only support editing/deleting your **last** comment:

```bash
gh pr comment 15 --edit-last --body "Updated comment"   # edit your last comment
gh pr comment 15 --delete-last                           # delete your last comment
```

To edit or delete an arbitrary comment by ID, use the API:

```bash
# Edit a PR timeline comment (issue comment)
gh api -X PATCH repos/{owner}/{repo}/issues/comments/<comment_id> -f body="Updated"

# Edit a review comment
gh api -X PATCH repos/{owner}/{repo}/pulls/comments/<comment_id> -f body="Updated"

# Delete a review comment
gh api -X DELETE repos/{owner}/{repo}/pulls/comments/<comment_id>
```

---

## GitHub Actions / CI

```bash
gh run list                             # recent runs for current branch
gh run list --branch main               # runs on a specific branch
gh run list --workflow "ci.yml"          # filter by workflow
gh run list --status failure             # filter by status
gh run view <run-id>                    # run summary
gh run view <run-id> --verbose          # show job steps
gh run view <run-id> --log              # full logs
gh run view <run-id> --log-failed       # logs only for failed steps
gh run view <run-id> --job <job-id>     # specific job
gh run watch <run-id>                   # stream status in real-time until done
gh run watch <run-id> --exit-status     # exit non-zero if run fails
gh run rerun <run-id>                   # rerun entire run
gh run rerun <run-id> --job <job-id>    # rerun specific job
gh run cancel <run-id>                  # cancel running workflow
gh run download <run-id>                # download artifacts
gh run download <run-id> --name build   # download specific artifact
```

### Workflows

```bash
gh workflow list                        # list all workflows
gh workflow view ci.yml                 # view workflow details
gh workflow view ci.yml --yaml          # view workflow YAML
gh workflow run ci.yml                  # trigger workflow_dispatch
gh workflow run ci.yml --ref develop    # trigger on specific ref
gh workflow run ci.yml -f version="1.0" -f env="prod"  # with inputs
gh workflow enable ci.yml               # enable disabled workflow
gh workflow disable ci.yml              # disable workflow
```

### Monitoring a run

**To watch a specific run**, first find its ID, then watch it:

```bash
# Find the run ID
gh run list --branch main --limit 1 --json databaseId --jq '.[0].databaseId'

# Watch it
gh run watch <run-id>

# Or watch with compact output (only relevant/failed steps)
gh run watch <run-id> --compact
```

`gh run watch` takes a **run ID**, not a branch name. To monitor a run on a specific branch, always look up the run ID first via `gh run list --branch <branch>`.

**For PR-specific checks**, use `gh pr checks` instead -- it shows all status checks on a PR and supports `--watch`:

```bash
gh pr checks 15 --watch
```

### Viewing failed logs

When a run fails, `--log-failed` is the most efficient way to see what went wrong:

```bash
gh run view <run-id> --log-failed
```

This shows only the output from failed steps, avoiding hundreds of lines of passing step output.

### Actions caches

```bash
gh cache list                           # list all caches
gh cache list --limit 50                # show more
gh cache delete <cache-id>              # delete specific cache
```

---

## Releases

```bash
gh release list                         # list releases
gh release view v1.0.0                  # view specific release
gh release create v1.0.0 --notes "Release notes" --title "Version 1.0.0"
gh release create v1.0.0 --generate-notes     # auto-generate notes
gh release create v1.0.0 --notes-file notes.md
gh release create v1.0.0 --draft               # draft release
gh release create v1.0.0 --prerelease          # pre-release
gh release create v1.0.0 ./dist/*.tar.gz       # with assets
gh release upload v1.0.0 ./file.tar.gz         # upload asset to existing release
gh release download v1.0.0                      # download all assets
gh release download v1.0.0 --pattern "*.tar.gz" # download matching assets
gh release edit v1.0.0 --notes "Updated notes"
gh release delete v1.0.0                        # delete (NEVER do this -- see Safety Protocol)
```

---

## Search

`gh search` lets you search across all of GitHub, not just the current repository:

```bash
gh search issues "label:bug state:open" --repo owner/repo
gh search prs "is:open review:required" --repo owner/repo
gh search code "TODO" --repo owner/repo
gh search commits "fix auth" --repo owner/repo
gh search repos "stars:>1000 language:python"
```

All search commands support `--json`, `--jq`, and `--limit` for structured output.

---

## Safety Protocol

**Your default role is read-only.** Do NOT proactively suggest, offer, or execute state-changing operations. Only perform write or mutating operations when the user explicitly asks for them.

### Tier 1 -- FORBIDDEN (never execute these)

These commands are **never** executed, regardless of what the user asks. If the user needs one of these, explain the consequences and tell them how to run it manually.

| Action | Command |
|--------|---------|
| Delete repo | `gh repo delete` |
| Delete release | `gh release delete` |
| Delete workflow runs | `gh run delete` |
| Destructive API calls | `gh api -X DELETE` on critical resources |
| Force push to default branch | `git push --force` to `main`/`master`/default |
| Hard reset | `git reset --hard` |

### Tier 2 -- EXPLICIT REQUEST ONLY (never suggest, never offer)

These commands are executed **only** when the user explicitly requests them with clear intent (e.g., "merge the PR", "close issue #42"). Never propose them, never include them in automated workflows, never ask "should I merge/close this?".

Before executing, **always** explain what will happen and ask for confirmation.

| Action | Command |
|--------|---------|
| Merge PR | `gh pr merge` |
| Merge bypassing checks | `gh pr merge --admin` (bypasses branch protection -- extra caution) |
| Close issue or PR | `gh issue close`, `gh pr close` |
| Delete issue | `gh issue delete` |
| Cancel workflow run | `gh run cancel` |
| Disable workflow | `gh workflow disable` |
| Modify secrets | `gh secret set`, `gh secret delete` |
| Modify variables | `gh variable set`, `gh variable delete` |
| Delete release assets | `gh release delete-asset` |
| Delete all caches | `gh cache delete --all` |
| Force push (non-default branch) | `git push --force` |
| Skip hooks | `--no-verify` |

### Tier 3 -- SAFE WITH CONFIRMATION

These operations can be proposed when relevant, but require a brief confirmation before execution.

| Action | Command |
|--------|---------|
| Update PR branch | `gh pr update-branch` |
| Update metadata (labels, assignees, etc.) | `gh pr edit`, `gh issue edit` |
| Change draft status | `gh pr ready`, `gh pr ready --undo` |
| Rerun workflow | `gh run rerun` |
| Trigger workflow | `gh workflow run` |

### Git safety

- **Prefer `gh pr update-branch`** over manual rebase + force push
- When in doubt about target branch, check the repo default: `gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name'`

---

## `gh api` -- last resort for advanced operations

> **Do NOT use `gh api` when a CLI subcommand can do the job.** For issues, PRs, runs, labels -- always use the dedicated subcommands first. Use `gh api` only for operations not covered by any subcommand (e.g., review comment replies, team membership, GraphQL queries).

```bash
gh api repos/{owner}/{repo}/collaborators                              # GET
gh api -X POST repos/{owner}/{repo}/issues -f title="New" -f body="..." # POST
gh api -X PATCH repos/{owner}/{repo}/pulls/15 -f title="Updated"      # PATCH
gh api repos/{owner}/{repo}/issues --paginate                          # paginate
```

### Placeholder variables

Inside a git repo, `{owner}`, `{repo}`, and `{branch}` are auto-resolved:

```bash
gh api repos/{owner}/{repo}/pulls    # resolves to the current repo
```

### Native `--jq` filtering

Unlike `glab` (which requires piping to external `jq`), `gh api` has **built-in `--jq` support**:

```bash
gh api repos/{owner}/{repo}/pulls --jq '.[].title'
gh api user --jq '.login'
gh api repos/{owner}/{repo}/contributors --jq '.[] | {login: .login, contributions: .contributions}'
```

Use `--jq` instead of piping to `jq` whenever possible -- it's faster and avoids a dependency.

### GraphQL

```bash
gh api graphql -f query='
  query {
    repository(owner: "owner", name: "repo") {
      pullRequests(states: OPEN, first: 10) {
        nodes {
          number
          title
          author { login }
          reviewDecision
        }
      }
    }
  }
'
```

For comprehensive API patterns (GraphQL, pagination, advanced queries), read `references/api-patterns.md`.
