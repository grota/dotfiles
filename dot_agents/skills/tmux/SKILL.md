---
name: tmux
description: Control tmux sessions for interactive CLIs and TUIs. Use this skill whenever you need to send keystrokes to a terminal, run interactive programs (vim, htop, ncurses apps, REPLs, fzf), capture output from long-running processes, or work with full-screen terminal applications. Essential for automating interactive shell workflows that can't be controlled via standard bash. Also use this when a program expects a TTY, needs Ctrl+C/Ctrl+D signals, or when you need to monitor a background process while doing other work.
---

# Tmux Skill

Use tmux to interact with programs that need a real terminal — interactive REPLs, TUIs, editors, long-running processes you want to monitor, anything that expects a TTY or needs keystroke-level control.

## Core Workflow

Every tmux interaction follows this pattern: create an isolated session, interact with it, and clean up. Here's the full flow:

```bash
# 1. If you just started using this skill you need to pick a unique socket name.
# You do that by listing the files in /tmp/tmux-$(id -u)/ and choosing a name that
# doesn't exist yet (to avoid collisions with user's tmux or other agents).
# Once you've picked a `$SOCKET` value, remember it and reuse it for every tmux command of yours, don't create a new socket per command.
ls /tmp/tmux-$(id -u)/

# 2. Create an isolated session
#    -L $SOCKET  → use our own tmux server (never touch the user's)
#    -f <(:)     → skip loading user's tmux.conf (their config might remap keys,
#                  change the prefix, or set options that break our automation)
tmux -L $SOCKET -f <(:) new-session -d -s main -x $COLUMNS -y $LINES "bash"

# 3. Interact: send input, wait for output, capture it
tmux -L $SOCKET send-keys -t main "echo hello" C-m
sleep 0.5
tmux -L $SOCKET capture-pane -t main -p

# 4. Clean up when done (orphaned servers waste resources and can confuse future runs)
tmux -L $SOCKET kill-server && rm -f /tmp/tmux-$(id -u)/$SOCKET
```

Once you've picked a `$SOCKET` value, reuse it for every tmux command in the task. Don't create a new socket per command.

## Sending Input

```bash
tmux -L $SOCKET send-keys -t main "your command here" C-m
```

### Special Keys

| Key | What it sends |
|-----|--------------|
| `C-m` | Enter |
| `C-c` | Ctrl+C (interrupt) |
| `C-d` | Ctrl+D (EOF) |
| `Tab` | Tab (autocomplete) |
| `Escape` | Escape |
| `Space` | Space (useful when building key sequences) |
| `Up` / `Down` | Arrow keys |
| `BSpace` | Backspace |

### Sending Literal Text

By default, `send-keys` interprets special sequences like `C-m` as keystrokes. If you need to send text that contains these patterns without interpretation, use the `-l` (literal) flag:

```bash
# This sends the literal string "C-m" rather than pressing Enter
tmux -L $SOCKET send-keys -t main -l "The sequence C-m means Enter"
# Then press Enter separately
tmux -L $SOCKET send-keys -t main C-m
```

This matters when sending code or text that contains characters tmux would otherwise interpret — semicolons, quotes, backslashes, or anything resembling a key binding.

## Capturing Output

```bash
# Capture what's currently visible in the pane
tmux -L $SOCKET capture-pane -t main -p

# Capture with scrollback history (last 200 lines)
tmux -L $SOCKET capture-pane -t main -p -S -200
```

`capture-pane -p` only returns what fits in the visible pane (determined by the `-x` and `-y` you set at session creation). If a command produced more output than the pane height, the top lines scroll off. Use `-S -<N>` to reach into the scrollback buffer — set N high enough to capture everything you need.

## Target Syntax

Use targets to address specific sessions, windows, or panes when you have more than one:

| Target | Meaning |
|--------|---------|
| `-t main` | Session named "main" (default pane) |
| `-t main:0` | Window 0 in session "main" |
| `-t main:1` | Window 1 |
| `-t main:0.0` | Pane 0 in window 0 |
| `-t main:0.1` | Pane 1 in window 0 |

## Waiting for Output

Interactive programs need time to process input and render output. There are two approaches:

### Fixed Delays

Simple and usually sufficient. Use `sleep` between sending input and capturing:

```bash
tmux -L $SOCKET send-keys -t main "python3 -c 'print(42)'" C-m
sleep 0.5
tmux -L $SOCKET capture-pane -t main -p
```

Adjust the delay based on what you're waiting for:
- `sleep 0.3` — fast commands (echo, simple REPL expressions)
- `sleep 0.5-1` — typical interactive programs starting up
- `sleep 2-5` — programs with slow startup (language servers, heavy apps)

### Polling (More Robust)

For cases where timing is unpredictable, poll until the expected output appears. This avoids both waiting too long and capturing too early:

```bash
# Wait for a specific prompt or output pattern
for i in $(seq 1 20); do
  OUTPUT=$(tmux -L $SOCKET capture-pane -t main -p)
  if echo "$OUTPUT" | grep -q ">>>"; then
    break
  fi
  sleep 0.5
done
```

Polling is better than fixed delays when: a program has variable startup time, you're waiting for a specific prompt, or you need to be sure a command finished before sending the next one.

## Error Handling

**Capture returns empty/stale output**: The program hasn't rendered yet. Increase the delay or switch to polling.

**Program exited unexpectedly**: The pane may have closed. Check if the session still exists:
```bash
tmux -L $SOCKET has-session -t main 2>/dev/null && echo "alive" || echo "dead"
```

## Examples

### Python REPL

```bash
SOCKET="tmux-agent-$(date +%s%N)"
tmux -L $SOCKET -f <(:) new-session -d -s main -x $COLUMNS -y $LINES "python3 -i"

# Wait for the >>> prompt
for i in $(seq 1 10); do
  OUTPUT=$(tmux -L $SOCKET capture-pane -t main -p)
  echo "$OUTPUT" | grep -q ">>>" && break
  sleep 0.5
done

tmux -L $SOCKET send-keys -t main "2 + 2" C-m
sleep 0.3
tmux -L $SOCKET capture-pane -t main -p

tmux -L $SOCKET send-keys -t main "exit()" C-m
tmux -L $SOCKET kill-server && rm -f /tmp/tmux-$(id -u)/$SOCKET
```

### Monitoring a Long-Running Process

```bash
SOCKET="tmux-agent-$(date +%s%N)"
tmux -L $SOCKET -f <(:) new-session -d -s main -x $COLUMNS -y $LINES "tail -f /var/log/syslog"
sleep 1

# Check output periodically — you can do other work between captures
tmux -L $SOCKET capture-pane -t main -p

# When done monitoring
tmux -L $SOCKET send-keys -t main C-c
sleep 0.3
tmux -L $SOCKET kill-server && rm -f /tmp/tmux-$(id -u)/$SOCKET
```

### Vim Automation

```bash
SOCKET="tmux-agent-$(date +%s%N)"
tmux -L $SOCKET -f <(:) new-session -d -s main -x $COLUMNS -y $LINES "vim /tmp/test.txt"
sleep 1  # vim takes a moment to start

# Enter insert mode, type text, save and quit
tmux -L $SOCKET send-keys -t main "i"
tmux -L $SOCKET send-keys -t main -l "Hello from tmux automation"
tmux -L $SOCKET send-keys -t main Escape
sleep 0.2
tmux -L $SOCKET send-keys -t main ":wq" C-m
sleep 0.3

tmux -L $SOCKET capture-pane -t main -p
tmux -L $SOCKET kill-server && rm -f /tmp/tmux-$(id -u)/$SOCKET
```

Note: the Vim example uses `send-keys -l` for the text content so that any special characters in the text are sent literally rather than interpreted as tmux key bindings.
