# tmux-dev

Manage development servers running in tmux sessions. This workflow helps monitor long-running processes without blocking the terminal.

## Start Development Server

To start a development server in a tmux session:

```
Please start the development server in a new tmux session:
- Navigate to the project directory
- Get repo name: REPO=$(basename $(git rev-parse --show-toplevel))
- Get branch name: BRANCH=$(git rev-parse --abbrev-ref HEAD)
- Create tmux session: tmux new-session -d -s "$REPO-$BRANCH" '[command]'
- Verify it's running with tmux list-sessions
```

The session name will automatically use the repository name and current branch name.

Example: "Start the Next.js dev server in tmux" (session will be named like 'my-app-feature/auth')

## Check Logs

To view logs from a running tmux session without attaching:

```
Show me the last [N] lines of logs from tmux session:
- Get repo name: REPO=$(basename $(git rev-parse --show-toplevel))
- Get branch name: BRANCH=$(git rev-parse --abbrev-ref HEAD)
- Use: tmux capture-pane -t "$REPO-$BRANCH" -p | tail -[N]
```

Example: "Show me the last 50 lines from the current project's tmux session"

## Monitor in Real-time

To attach and monitor logs interactively:

```
Attach me to the tmux session to see real-time logs:
- Get repo name: REPO=$(basename $(git rev-parse --show-toplevel))
- Get branch name: BRANCH=$(git rev-parse --abbrev-ref HEAD)
- Use: tmux attach -t "$REPO-$BRANCH"
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
Stop the tmux session:
- Get repo name: REPO=$(basename $(git rev-parse --show-toplevel))
- Get branch name: BRANCH=$(git rev-parse --abbrev-ref HEAD)
- Use: tmux kill-session -t "$REPO-$BRANCH"
```

## Common Patterns

### Quick Status Check
"Is the dev server for this project still running? Show me the last 20 lines of logs"

### Debugging
"Show me the last 100 lines from this project's tmux session, I think there's an error"

### Multiple Projects
"Start frontend on port 3000 and backend on port 8000 in separate tmux sessions named after their respective repos and branches"

### Project-specific Development
"Start the Next.js dev server in tmux" (automatically uses current repo and branch: my-app + feature/user-auth → session named 'my-app-feature/user-auth')

### Multi-project Workflow
- `dotfiles-main` (dotfiles repo on main branch)
- `my-app-feature/auth` (my-app repo on feature/auth branch)
- `api-server-bugfix/cors` (api-server repo on bugfix/cors branch)
