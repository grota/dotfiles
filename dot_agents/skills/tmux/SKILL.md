---
name: tmux
description: Control tmux sessions for interactive CLIs and TUIs. Use this skill whenever you need to send keystrokes to a terminal, run interactive programs (vim, htop, REPLs), capture output from long-running processes, or work with full-screen terminal applications. Essential for automating interactive shell workflows that can't be controlled via standard bash.
---

# Tmux Skill

This skill enables control of tmux sessions for isolated interactive CLI/TUI operations. Use this when you need to interact with programs that require a real terminal (interactive REPLs, TUIs, etc.).

## Isolation

**Always use a dedicated tmux socket** (operate only on your own tmux server) to avoid interfering with the user's or other agents' tmux servers:

1. Once, at the beginning, before the very first tmux invocation **check for other existing sockets first**:
   ```bash
   ls /tmp/tmux-$(id -u)/tmux-agent-* 2>/dev/null
   ```

2. **Choose a new socket file name** (an available non existing socket file), for example:
   ```bash
   SOCKET="tmux-agent-$(date +%s%N)"
   ```

3. **Always use this flag when executing tmux**: `-L $SOCKET` to use chose socket file name (avoid using user's or other agents' tmux servers)

4. The **very first** tmux invocation **must use this flag** `-f <(:)` to avoid loading user's tmux config

## Session Management

### Create a Session

```bash
SOCKET="tmux-agent-$(date +%s%N)"
tmux -L $SOCKET -f <(:) new-session -d -s main -x $COLUMNS -y $LINES "bash"
```

### Send Input

```bash
tmux -L $SOCKET send-keys -t main "echo hello world" C-m
tmux -L $SOCKET send-keys -t main "python3" C-m
```

Special keys:
- `C-m` = Enter
- `C-c` = Ctrl+C
- `C-d` = Ctrl+D
- `Tab` = Tab
- `Escape` = Escape

### Capture Output

```bash
tmux -L $SOCKET capture-pane -t main -p
tmux -L $SOCKET capture-pane -t main -p -S -100  # with history
```

### Cleanup

```bash
tmux -L $SOCKET kill-session -t main
# Or kill the entire server:
tmux -L $SOCKET kill-server
```

## Target Syntax

| Target | Meaning |
|--------|---------|
| `-t main` | The main session |
| `-t main:0` | Window 0 |
| `-t main.0` | Pane 0 |
| `-t main:1` | Window 1 |

## Workflow Pattern

```bash
# 1. Check for existing agent sockets
ls /tmp/tmux-$(id -u)/tmux-agent-* 2>/dev/null

# 2. Pick a socket name (or reuse existing)
SOCKET="tmux-agent-$(date +%s%N)"

# 3. Create session
tmux -L $SOCKET -f <(:) new-session -d -s main -x $COLUMNS -y $LINES "python3"

# 4. Interact (add delays between send and capture)
sleep 0.5
tmux -L $SOCKET send-keys -t main "2 + 2" C-m
sleep 0.5
tmux -L $SOCKET capture-pane -t main -p

# 5. Always clean up
tmux -L $SOCKET kill-session -t main
```

## Important Notes

1. **Always clean up** - Kill the session when done
2. **Add delays** - Interactive programs need time to respond
3. **Capture after sending** - Always capture output after sending input
4. **Use empty config** - `-f <(:)` prevents loading user's tmuxrc
5. **Reuse socket** - Once chosen, use the same `-L $SOCKET` for all operations in a task

## Examples

### Python REPL

```bash
SOCKET="tmux-agent-$(date +%s%N)"

tmux -L $SOCKET -f <(:) new-session -d -s main -x $COLUMNS -y $LINES "python3 -i"
sleep 0.5

tmux -L $SOCKET send-keys -t main "2 + 2" C-m
sleep 0.5
tmux -L $SOCKET capture-pane -t main -p

tmux -L $SOCKET send-keys -t main "exit()" C-m
tmux -L $SOCKET kill-session -t main
```

### Long-running process

```bash
SOCKET="tmux-agent-$(date +%s%N)"

tmux -L $SOCKET -f <(:) new-session -d -s main -x $COLUMNS -y $LINES "tail -f /var/log/syslog"
sleep 0.5

# Check periodically
tmux -L $SOCKET capture-pane -t main -p

# Cleanup
tmux -L $SOCKET kill-session -t main
```

### Vim automation

```bash
SOCKET="tmux-agent-$(date +%s%N)"

tmux -L $SOCKET -f <(:) new-session -d -s main -x $COLUMNS -y $LINES "vim /tmp/test.txt"
sleep 0.5

tmux -L $SOCKET send-keys -t main "i"
tmux -L $SOCKET send-keys -t main "Hello vim" C-m
tmux -L $SOCKET send-keys -t main Escape
tmux -L $SOCKET send-keys -t main ":wq" C-m

tmux -L $SOCKET capture-pane -t main -p
tmux -L $SOCKET kill-session -t main
```

