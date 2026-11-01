---
name: tmux
description: Drive programs that need a real terminal through a private tmux server. Use when a program needs a TTY or keystrokes (REPLs, vim, htop, fzf, ncurses or full-screen TUIs, interactive prompts, Ctrl+C/Ctrl+D). For plain non-interactive commands, prefer your harness's own background execution if it has one.
---

# tmux

## Rules

- Use your own server with `-L <socket>`. Never touch the user's tmux.
- Pick the socket name once (for example `agent-$RANDOM`) and use the same name for the whole task. If your harness starts a fresh shell per command, write the literal name each time instead of a variable.
- Start with `-f /dev/null` so the user's `tmux.conf` cannot remap keys or change options.
- Always pass an explicit size (`-x 200 -y 50`). Agent shells are usually non-interactive, so `$COLUMNS` and `$LINES` may be empty, and tmux then fails with `width invalid`.
- Wait for completion with `wait-for`, or poll with a timeout. Do not rely on a bare `sleep`. Wrap blocking calls in `timeout` so a stuck program cannot outlast your harness's command time limit.
- Clean up with `kill-server`, then remove the socket file, which tmux leaves behind.

## Workflow

```bash
S=agent-12345   # chosen once; repeat literally if shell state does not persist

tmux -L $S -f /dev/null new-session -d -s main -x 200 -y 50 bash

# Shell command: signal completion from inside the pane, then block on it.
tmux -L $S send-keys -t main 'make test; tmux wait-for -S done' C-m
timeout 300 tmux -L $S wait-for done
tmux -L $S capture-pane -p -J -t main -S -200

# TUI or REPL: poll the screen for an expected string, and report a timeout.
tmux -L $S send-keys -t main 'python3 -q' C-m
ok=0
for i in $(seq 1 40); do
  tmux -L $S capture-pane -p -t main | grep -q '>>>' && { ok=1; break; }
  sleep 0.25
done
[ $ok = 1 ] || echo "timed out waiting for prompt"

tmux -L $S kill-server
rm -f "${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/$S"
```

## Notes

- `send-keys` translates an argument only when the whole argument is a key name (`C-m`, `Enter`, `Escape`, `C-c`, `C-d`, `Tab`, `BSpace`, `Up`). Use `-l` to send text that could be read as a key name, then send `C-m` separately.
- `capture-pane -p` prints only the visible screen. Add `-S -N` for N lines of scrollback and `-J` to join wrapped lines.
- `tmux -L $S has-session -t main` tells whether the program is still running.
- `wait-for` works only for shell commands. For a TUI, poll the screen.
- The example uses bash syntax. `timeout` is GNU coreutils; on macOS it may be missing (`gtimeout` from Homebrew, or a polling loop instead).
