# tmux-dev

Manage development servers running in tmux sessions. This workflow helps monitor long-running processes without blocking the terminal.

## Start Development Server

To start a development server in a tmux session:

```
Please start the development server in a new tmux session named [session-name]:
- Navigate to the project directory
- Create tmux session: tmux new-session -d -s [session-name] '[command]'
- Verify it's running with tmux list-sessions
```

Example: "Start the Next.js dev server in tmux session 'my-app'"

## Check Logs

To view logs from a running tmux session without attaching:

```
Show me the last [N] lines of logs from tmux session [session-name]:
- Use: tmux capture-pane -t [session-name] -p | tail -[N]
```

Example: "Show me the last 50 lines from the insta-admin tmux session"

## Monitor in Real-time

To attach and monitor logs interactively:

```
Attach me to the tmux session [session-name] to see real-time logs:
- Use: tmux attach -t [session-name]
- Note: User can detach with Ctrl+B then D
```

## List Sessions

To see all running tmux sessions:

```
Show me all running tmux sessions:
- Use: tmux list-sessions
```

## Stop Server

To stop a development server:

```
Stop the tmux session [session-name]:
- Use: tmux kill-session -t [session-name]
```

## Common Patterns

### Quick Status Check
"Is the insta-admin server still running? Show me the last 20 lines of logs"

### Debugging
"Show me the last 100 lines from the backend session, I think there's an error"

### Multiple Servers
"Start frontend on port 3000 and backend on port 8000 in separate tmux sessions"
