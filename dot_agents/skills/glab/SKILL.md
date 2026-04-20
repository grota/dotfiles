---
name: glab
description: How to use the glab CLI to work with GitLab issues, merge requests, CI/CD pipelines, repository files, and releases. Use this skill whenever the user provides a URL containing "gitlab" in the hostname (e.g., gitlab.com, gitlab.example.com), mentions merge requests, GitLab issues, GitLab CI pipelines, or wants to interact with a GitLab remote. Also use this skill when the user mentions "glab", "MR", "merge request", or when you detect the git remote points to a GitLab instance (look for "gitlab" in the remote URL). This includes GitLab file URLs (raw files, blobs, tree views) -- use glab api to fetch file contents instead of WebFetch or curl. This skill is the GitLab equivalent of using `gh` for GitHub -- if the project is on GitLab, use this skill instead.
---

# glab CLI Skill

Use the `glab` CLI for ALL GitLab-related tasks including working with issues, merge requests, CI/CD pipelines, and releases. If given a GitLab URL, use `glab` to get the information needed.

## Before you start

1. **Detect GitLab URLs**: If the user provided a URL containing "gitlab" in the hostname, this is a GitLab resource. Do NOT use WebFetch, curl, or browser-based tools -- GitLab instances require authentication that only `glab` can provide. Extract the hostname and project path from the URL and proceed with `glab` commands. This applies to **all** GitLab URL types, including file URLs (`/-/raw/`, `/-/blob/`, `/-/tree/`) -- see the "Repository files" section for how to fetch file contents via `glab api`.
2. **Confirm it's a GitLab project**: check `git remote -v` for "gitlab" in the URL. If so, use `glab` (not `gh`).
3. **Verify authentication**: run `glab auth status`. If not authenticated for the relevant hostname, **stop and ask the user** -- do not proceed.

## CLI-first principle

**Always prefer glab subcommands** (`glab issue list`, `glab mr list`, `glab ci status`, etc.) over raw `glab api` calls. The CLI subcommands provide better output formatting, pagination, and are less error-prone. Use `glab api` **only** when no subcommand covers the operation (see the `glab api` section below).

## Targeting a project

Before running any `glab` command, determine the project context:

1. **User provided a GitLab URL** (e.g., `https://gitlab.example.com/team/project/-/issues/42` or `https://gitlab.example.com/team/project/-/boards/1`):
   Extract the **hostname** and **group/project path** from the URL, then use `GITLAB_HOST` + `-R`:
   ```bash
   # URL: https://gitlab.example.com/team/project/-/boards/123
   # Extracted hostname: gitlab.example.com
   # Extracted path: team/project
   GITLAB_HOST=gitlab.example.com glab issue list -R team/project --milestone "Sprint 1" --all
   GITLAB_HOST=gitlab.example.com glab milestone list --project team/project --state active
   ```

2. **Inside a git repo with a GitLab remote**: no `-R` or `GITLAB_HOST` needed, `glab` detects the project and hostname from the remote automatically.

3. **No URL provided and not inside a git repo**: **ask the user** for the full GitLab project URL before proceeding. Do not guess or assume a project.

### Self-hosted instances: always use `GITLAB_HOST`

For **self-hosted GitLab instances** (anything other than `gitlab.com`), always set the `GITLAB_HOST` environment variable. This is the only reliable method that works across **all** subcommands.

**Do NOT** rely on `-R <hostname>/<group>/<project>` alone -- some subcommands (e.g., `glab milestone list`) ignore the hostname in the `-R` flag and default to `gitlab.com`. Using `GITLAB_HOST` avoids this inconsistency.

**Do NOT** use `--hostname` -- it is not a valid flag on most subcommands (it only works on `glab auth` and `glab api`).

```bash
# CORRECT -- works for ALL subcommands on self-hosted instances:
GITLAB_HOST=gitlab.example.com glab issue list -R team/project --all
GITLAB_HOST=gitlab.example.com glab milestone list --project team/project --state active
GITLAB_HOST=gitlab.example.com glab mr list -R team/project

# WRONG -- may silently hit gitlab.com instead of your self-hosted instance:
glab milestone list -R gitlab.example.com/team/project --project team/project
```

## Handling auth errors

If any `glab` command fails with "Unauthenticated", "401", "403", or "connection refused", **stop immediately**. Do NOT work around auth failures with WebFetch, curl, or `gh`. Self-hosted GitLab instances are private -- those fallbacks will also fail.

Present the user with these options:

### Option 1: OAuth login (preferred -- more secure, tokens auto-refresh)

```bash
glab auth login --hostname <hostname> --use-keyring
# Select "Web" → browser opens → authorize → done
```

If OAuth fails (no OAuth app configured on the instance), fall back to a PAT.

### Option 2: Personal Access Token

Check git protocol to recommend minimal scopes:

- **SSH users** (`git@...` remote): `api` scope is sufficient
- **HTTPS users** (`https://...` remote): `api` + `write_repository`

Tell the user to generate a token at: `https://<hostname>/-/user_settings/personal_access_tokens?scopes=api,write_repository` — recommend a short expiry (30-90 days).

```bash
glab auth login --hostname <hostname> --token <token> --use-keyring
```

### Option 3: Skip the operation

**Always use `--use-keyring`** to store credentials in the OS keyring. Never store tokens in plaintext config.

## Core terminology

| GitHub | GitLab | CLI |
|--------|--------|-----|
| Pull Request | **Merge Request** | `glab mr` |
| Gist | **Snippet** | `glab snippet` |
| Actions | **CI/CD** | `glab ci` |
| `OWNER/REPO` | `GROUP/PROJECT` (supports nesting: `GROUP/SUBGROUP/PROJECT`) | -- |
| PR `#15` | MR `!15` | -- |

Issues use `#`, merge requests use `!`.

---

## Writing on behalf of the user

Whenever you create or post content on GitLab on behalf of the user — including **MR descriptions** (`glab mr create`), **issue descriptions** (`glab issue create`), **comments/notes** (`glab issue note`, `glab mr note`), or **`glab api` body fields** — you **must** prepend the following header to make it clear the content was authored by an AI agent acting on behalf of the user:

```
> :robot: _This was written by an AI agent on behalf of @<username>._
```

To get the current authenticated username run:

```bash
GITLAB_HOST=<hostname> glab api user | jq -r '.username'
```

> **Note:** `glab api` does not support `--jq` (that's a `gh` feature). Always pipe to `jq` instead.

Before writing any content, **always fetch the username first** and embed it in the header. Do not hardcode a username or leave the placeholder unfilled:

```bash
# Step 1: fetch the username (do this once per session)
GL_USERNAME=$(GITLAB_HOST=<hostname> glab api user | jq -r '.username')

# Step 2: use it in the content
GITLAB_HOST=gitlab.example.com glab mr create \
  --title "feat: add dark mode" \
  --description "> :robot: _This was written by an AI agent on behalf of @${GL_USERNAME}._

## Summary

- Adds dark mode toggle to settings page
- ..."
```

**Example** — adding a note to issue #42:

```bash
GITLAB_HOST=gitlab.example.com glab issue note 42 \
  -R group/project \
  --message "> :robot: _This was written by an AI agent on behalf of @${GL_USERNAME}._

## Triage

Root cause identified: ..."
```

This applies to **every** piece of content the agent creates, regardless of length or context. Never skip the header.

> **Heredoc warning:** when using `cat <<EOF` to build the body, **never** single-quote the delimiter (`<<'EOF'`). Single-quoted heredocs suppress variable expansion and produce the literal string `$GL_USERNAME` instead of the resolved value. Always use an unquoted delimiter:
>
> ```bash
> glab mr create --title "feat: add dark mode" --description "$(cat <<EOF
> > :robot: _This was written by an AI agent on behalf of @${GL_USERNAME}._
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
glab issue create --title "Bug: ..." --description "..." --label "type::bug,priority::high" --assignee "@me"
glab issue list --assignee=@me                    # list my issues
glab issue list --label="bug" --search="login"    # filter and search
glab issue view 42 --comments                     # view with comments
glab issue note 42 --message "Root cause found."  # add a comment
glab issue update 42 --label "confirmed"          # update metadata
glab issue close 42                               # close (ask confirmation first)
glab issue reopen 42
```

### State filtering (open / closed / all)

`glab` does **not** have a `--state` flag (that's `gh`, not `glab`) — using it fails with "Unknown flag". Use these flags instead:

| What you want | `glab issue list` | `glab mr list` |
|---|---|---|
| Open only (default) | _(no flag)_ | _(no flag)_ |
| Closed only | `--closed` | `--closed` |
| All (open + closed) | `--all` | `--all` |
| Merged only | n/a | `--merged` |

> **Closing/reopening with a comment**: `glab issue close` and `glab issue reopen` do not accept `--message`. Add a note first: `glab issue note 42 --message "..."`, then `glab issue close 42`.

### Issue template selection

Many GitLab projects define issue templates (stored in `.gitlab/issue_templates/`) that encode the team's expected structure -- sections to fill, checklists, labels via quick actions. Skipping these creates issues that don't match the project's conventions and forces manual cleanup.

Before creating any issue, check for templates:

1. **List templates**: `glab api projects/:id/templates/issues` -- returns `[{key, name}, ...]`. If empty or 404, the project has none; proceed without a template.
2. **Present choices**: show the available template names and ask the user which one to use.
3. **Fetch the selected template**: `glab api projects/:id/templates/issues/<key>` -- returns `{name, content}` with the full markdown body.
4. **Fill in the template**: use the template content as the issue description. Ask the user for any information the template sections require that they haven't provided yet.

To list just the template names: `glab api projects/:id/templates/issues | jq '.[].name'`.

### Label selection process

If the user specified exact labels, use them. Otherwise:

1. **Discover available labels**: `glab label list` (or `glab api projects/:id/labels` for more detail)
2. **Propose labels that fit** the issue context -- suggest scoped labels (e.g., `priority::high`, `type::bug`) when they exist in the project. Scoped labels use `::` and auto-remove conflicting labels in the same scope.
3. **Ask the user to confirm or adjust** before creating the issue.

Do NOT invent label names. Only propose labels that actually exist in the project.

**Create an MR directly from an issue**: `glab mr for 42` creates a branch and linked MR that auto-closes the issue on merge.

---

## Merge Requests

### Creating MRs

```bash
glab mr create --title "Fix login crash" --description "Closes #42" \
  --target-branch develop --reviewer "marco" --assignee "@me"
glab mr create --fill              # title/description from commits
glab mr create --draft --fill      # draft MR
glab mr create --fill --squash-before-merge --remove-source-branch  # with merge behavior flags
```

Include `Closes #42` or `Fixes #42` in the description to auto-close issues on merge.

> **`--squash` vs `--squash-before-merge`**: these are different flags on different commands. `glab mr create` accepts `--squash-before-merge` (configures the MR so commits will be squashed when eventually merged). `glab mr merge` accepts `--squash` (squashes commits at merge time). Using `--squash` with `glab mr create` will fail with "Unknown flag". Same applies to `--remove-source-branch`: both commands support it, but `--when-pipeline-succeeds` is only available on `glab mr merge`.

### MR title format

MR titles must follow the [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) format:

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

**MR creation checklist** (follow this carefully):

1. **Inspect branch state**: `git status`, `git log <base>...HEAD --oneline`, `git diff <base>...HEAD`
2. **Draft title/description from the actual diff** -- reference specific files, functions, behaviors. Do not just restate the user's request.
3. **Push**: `git push -u origin HEAD` if not yet pushed.
4. **Create**: `glab mr create` with all relevant flags.
5. **Return the MR URL** to the user.

### Reviewing and managing MRs

```bash
glab mr view 15 --comments          # view MR with comments
glab mr diff 15                     # see the diff
glab mr list --reviewer=@me         # MRs needing my review
glab mr checkout 15                 # checkout locally
glab mr note 15 --message "LGTM"   # leave a comment
glab mr approve 15                  # formal approval (separate from notes)
glab mr revoke 15                   # revoke approval
glab mr merge 15 --squash --remove-source-branch --when-pipeline-succeeds
glab mr rebase 15                   # rebase onto target
glab mr update 15 --add-label "reviewed"
glab mr close 15                    # close without merging
```

> **`close`/`reopen` do NOT accept `--message`**: unlike `gh pr close --comment`, `glab mr close` and `glab mr reopen` only accept `--repo` -- there is no `--message` or `--comment` flag. The same applies to `glab issue close` and `glab issue reopen`. To close (or reopen) with an explanation, add a note first as a separate command:
>
> ```bash
> # CORRECT -- note first, then close:
> glab mr note 15 --message "Closing: superseded by !20."
> glab mr close 15
>
> # WRONG -- fails with "Unknown flag: --message":
> glab mr close 15 --message "Closing: superseded by !20."
> ```

**Code review workflow**: view MR -> read diff -> check CI (`glab ci status`) -> read comments -> leave feedback -> approve or request changes.

Approval and notes are separate commands -- `glab mr approve` handles GitLab's formal approval system, `glab mr note` posts a comment.

---

## CI/CD

### TTY-only commands -- do NOT use

`glab ci view` is a **full-screen terminal UI** (TUI) that requires an interactive TTY with keyboard input. It will **always fail** in non-interactive contexts (agent bash tools, scripts, piped commands). Never use it.

| Command | Why it fails | Use instead |
|---------|-------------|-------------|
| `glab ci view` | Requires interactive TTY | `glab ci get` (structured data) or `glab ci status` (text summary) |

### Pipeline commands

```bash
glab ci status                       # pipeline status for current branch
glab ci status --branch main         # pipeline status for a specific branch
glab ci status --branch main --live  # stream status in real-time until pipeline completes
glab ci get                          # pipeline details as JSON (current branch)
glab ci get -b main                  # pipeline details for a specific branch
glab ci get -p <pipeline-id>         # pipeline details for a specific pipeline ID
glab ci get -p <pipeline-id> -d      # include extended job details
glab ci get -p <pipeline-id> -F json # explicit JSON output format
glab ci list                         # recent pipelines for current branch/project
glab ci list --per-page 10           # show more pipelines
glab ci trace                        # stream logs of the active job on current branch
glab ci trace --branch main          # stream logs for a specific branch
glab ci trace --branch main -p <id>  # stream logs for a specific pipeline ID
glab ci trace <job-name>             # stream logs for a specific job by name
glab ci run                          # trigger new pipeline
glab ci retry <pipeline-id>          # retry failed pipeline
glab ci cancel <pipeline-id>         # cancel running pipeline
glab ci artifact <refName> <jobName> # download artifacts (deprecated: use `glab job artifact`)
glab ci lint                         # validate .gitlab-ci.yml syntax
```

**Important:** `glab ci get` accepts **zero positional arguments**. The pipeline ID must be passed via the `-p` / `--pipeline-id` flag, not as a positional argument. Passing it as `glab ci get <id>` will fail with "Accepts 0 arg(s)".

Run `glab ci lint` before committing CI config changes to catch syntax errors early.

### Branch targeting

`glab ci status` and `glab ci trace` default to the **current git branch**. When monitoring pipelines on other branches (e.g., `main` after a push), use `--branch`:

```bash
glab ci status --branch main              # one-shot status check
glab ci status --branch main --live       # stream until pipeline finishes
glab ci trace --branch main               # stream active job logs on main
```

Without `--branch`, these commands look for a pipeline on the current branch, and may fail if none exists.

### Monitoring a specific pipeline

**Preferred: `--live` flag** — streams pipeline status in real-time until the pipeline completes (success, failed, or canceled). No polling loop needed:

```bash
glab ci status --branch main --live
```

**For pipeline details** (non-interactive, structured data):

```bash
# Get pipeline details by ID (JSON output)
glab ci get -p <pipeline-id>

# With extended job details
glab ci get -p <pipeline-id> -d
```

**For job-level detail** within a specific pipeline:

```bash
# 1. Find the pipeline ID
glab ci list --per-page 5

# 2. Stream logs of a specific pipeline
glab ci trace --branch main --pipeline-id <pipeline-id>

# 3. Check individual job statuses via API (when you need structured data beyond what `glab ci get -d` provides)
glab api "projects/:id/pipelines/<pipeline-id>/jobs" | jq '.[] | {name: .name, status: .status, stage: .stage}'
```

---

## Repository files

There is no `glab` subcommand for fetching file contents from a repository. Use `glab api` with the GitLab Repository Files API. This is the correct approach whenever a user shares a GitLab file URL or asks to read a file from a GitLab project -- **never** use WebFetch or curl, because GitLab instances (especially self-hosted ones) require authentication.

### Recognizing file URLs

GitLab file URLs follow these patterns:

| URL pattern | Meaning |
|---|---|
| `.../<project>/-/raw/<branch>/<path>` | Raw file content |
| `.../<project>/-/blob/<branch>/<path>` | File viewer (same file, different UI) |
| `.../<project>/-/tree/<branch>/<path>` | Directory listing |

When you see any of these, extract the **hostname**, **project path**, **branch**, and **file path**, then use `glab api`.

**Example** -- parsing a real URL:

```
URL: https://gitlab.example.com/team/infra/platform/-/raw/main/deploy/docker-compose.yml?ref_type=heads

  hostname: gitlab.example.com
  project:  team/infra/platform
  branch:   main
  file:     deploy/docker-compose.yml
```

Ignore query parameters like `?ref_type=heads` -- they are UI artifacts, not needed for the API.

### Fetching a file

File paths in the API endpoint must be **URL-encoded** (slashes become `%2F`):

```bash
# File at root (no slashes in path -- no encoding needed):
GITLAB_HOST=gitlab.example.com glab api \
  "projects/team%2Finfra%2Fplatform/repository/files/.gitlab-ci.yml/raw?ref=main"

# File in a subdirectory (slashes must be encoded):
# deploy/docker-compose.yml → deploy%2Fdocker-compose.yml
GITLAB_HOST=gitlab.example.com glab api \
  "projects/team%2Finfra%2Fplatform/repository/files/deploy%2Fdocker-compose.yml/raw?ref=main"
```

The `/raw` suffix returns the file content directly as plain text. Without `/raw`, the API returns JSON with base64-encoded content -- use `/raw` unless you need the metadata.

When you're **inside the target repo's git clone**, the `:id` placeholder is resolved automatically:

```bash
glab api "projects/:id/repository/files/.gitlab-ci.yml/raw?ref=main"
```

### Browsing a directory

```bash
# List files in a directory
GITLAB_HOST=gitlab.example.com glab api \
  "projects/team%2Finfra%2Fplatform/repository/tree?ref=main&path=deploy" \
  | jq '.[].name'

# Recursive listing (use recursive=true)
glab api "projects/:id/repository/tree?ref=main&recursive=true" | jq '.[].path'
```

### Cross-project file access

When the user references a file from a **different project** than the one you're currently in, you must URL-encode the full project path (slashes as `%2F`) and set `GITLAB_HOST`:

```bash
# Reading a file from another project on the same instance:
GITLAB_HOST=gitlab.example.com glab api \
  "projects/other-team%2Fshared-configs/repository/files/templates%2F.gitlab-ci.yml/raw?ref=main"
```

---

## Safety Protocol

**Your default role is read-only.** Do NOT proactively suggest, offer, or execute state-changing operations. Only perform write or mutating operations when the user explicitly asks for them.

### Tier 1 -- FORBIDDEN (never execute these)

These commands are **never** executed, regardless of what the user asks. If the user needs one of these, explain the consequences and tell them how to run it manually.

| Action | Command |
|--------|---------|
| Delete repo | `glab repo delete` |
| Delete release | `glab release delete` |
| Destructive API calls | `glab api -X DELETE ...` on critical resources |
| Force push to default branch | `git push --force` to `main`/`master`/default |
| Hard reset | `git reset --hard` |

### Tier 2 -- EXPLICIT REQUEST ONLY (never suggest, never offer)

These commands are executed **only** when the user explicitly requests them with clear intent (e.g., "merge the MR", "close issue #42"). Never propose them, never include them in automated workflows, never ask "should I merge/close this?".

Before executing, **always** explain what will happen and ask for confirmation.

| Action | Command |
|--------|---------|
| Merge MR | `glab mr merge` |
| Close issue or MR | `glab issue close`, `glab mr close` |
| Delete issue or MR | `glab issue delete`, `glab mr delete` |
| Cancel pipeline | `glab ci cancel` |
| Force push (non-default branch) | `git push --force` |
| Skip hooks | `--no-verify` |

### Tier 3 -- SAFE WITH CONFIRMATION

These operations can be proposed when relevant, but require a brief confirmation before execution.

| Action | Command |
|--------|---------|
| Rebase MR | `glab mr rebase` |
| Update metadata (labels, assignees, etc.) | `glab mr update`, `glab issue update` |

### Git safety

- **Prefer `glab mr rebase`** over manual rebase + force push
- When in doubt about target branch, check the project default rather than assuming `main`

---

## Milestones -- `id` vs `iid`

Always look up milestones **by title**, not by numeric ID — this avoids the `id`/`iid` confusion entirely:

```bash
# CORRECT -- lookup by title:
GITLAB_HOST=gitlab.example.com glab api "projects/group%2Frepo/milestones?title=Sprint+49"

# WRONG -- iid (project-scoped) used as path param → 404:
GITLAB_HOST=gitlab.example.com glab api "projects/group%2Frepo/milestones/58"
```

If you must use a numeric ID, use the global `id` field (not `iid`) from the API response:
`{ "id": 551, "iid": 58 }` → use `551` in the path, never `58`.

---

## File uploads (images, attachments)

`glab api` **cannot** do multipart file uploads. It only sends JSON request bodies -- the `-F file=@path` flag reads the file as a string value into a JSON field, not as `multipart/form-data`. For binary files (images, PDFs, etc.) this produces a 400 Bad Request.

There is no `glab upload` subcommand for project uploads either (`glab release upload` only handles release assets).

**Use `curl` with the GitLab project uploads API instead.** Extract the auth token from `glab` for the `curl` request:

### Step 1: Get the token and project ID

```bash
# Get the token (look for the "Token found:" line)
GITLAB_HOST=<hostname> glab auth status -t

# Get the numeric project ID (inside a git repo)
GITLAB_HOST=<hostname> glab api projects/:id | jq '.id'
```

### Step 2: Upload the file

**Detecting token type:** if `glab auth status` shows `Logged in ... (keyring)` without mentioning a PAT (browser login), it's an OAuth token -- use `Authorization: Bearer`. If you provided a PAT directly, use `PRIVATE-TOKEN`. When in doubt, try Bearer first -- if you get a 401, retry with `PRIVATE-TOKEN`.

```bash
curl --silent --show-error --request POST \
  --header "Authorization: Bearer <token>" \
  --form "file=@path/to/image.png" \
  "https://<hostname>/api/v4/projects/<project-id>/uploads"
```

### Step 3: Use the returned markdown URL

The upload returns JSON with a `markdown` field ready to paste into descriptions:

```json
{
  "id": 12345,
  "alt": "image",
  "url": "/uploads/<hash>/image.png",
  "markdown": "![image](/uploads/<hash>/image.png)"
}
```

Use this in MR/issue descriptions or comments:

```bash
GITLAB_HOST=<hostname> glab mr update 4 --description "## Screenshot

![image](/uploads/<hash>/image.png)"
```

---

## `glab api` -- last resort for advanced operations

> **Do NOT use `glab api` when a CLI subcommand can do the job.** For issues, MRs, CI, labels -- always use the dedicated subcommands first. Use `glab api` only for operations not covered by any subcommand (e.g., group projects, project members, GraphQL queries, custom endpoints).

```bash
glab api projects/:id/members                                        # GET
glab api -X POST projects/:id/issues -f title="New" -f description="..." # POST
glab api -X PUT projects/:id/merge_requests/15 -f title="Updated"   # PUT
glab api projects/:id/issues --paginate                              # paginate
```

> **`--paginate` concatenation:** `--paginate` outputs each page's JSON array back-to-back (`[...][...]`), which is not valid JSON. Always merge with `jq -s 'add'`:
>
> ```bash
> # WRONG -- breaks on multi-page results:
> glab api projects/:id/issues --paginate | jq '.[].title'
>
> # CORRECT:
> glab api projects/:id/issues --paginate | jq -s 'add | .[].title'
> ```

### Group-level operations

There is no `glab` subcommand for group operations -- use `glab api` with URL-encoded group paths (slashes as `%2F`):

```bash
# List projects in a group
GITLAB_HOST=gitlab.example.com glab api \
  "groups/team%2Fsubgroup/projects" --paginate | jq -s 'add | .[].name' -r | sort

# Include descendant subgroups
GITLAB_HOST=gitlab.example.com glab api \
  "groups/team%2Fsubgroup/projects?include_subgroups=true" --paginate \
  | jq -s 'add | .[].path_with_namespace' -r
```

Placeholder variables (auto-resolved inside a git repo): `:id`, `:fullpath`, `:repo`.

For comprehensive API patterns (GraphQL, pagination, groups, advanced queries), read `references/api-patterns.md`.
