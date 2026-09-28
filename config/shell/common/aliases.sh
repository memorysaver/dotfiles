# Aliases supported by both Bash and Zsh.
# On Omarchy the platform Claude Code launcher is `cx`
# (`claude --permission-mode auto`). These keep --rc for remote control and
# remain the spelling on non-Omarchy machines.
alias ccusage='ccusage blocks --live'
alias ccyolo='claude --dangerously-skip-permissions --rc'
alias agyolo='agy --dangerously-skip-permissions'
alias codexyolo='codex --yolo'
alias ccyolow='claude --dangerously-skip-permissions --rc -w'
alias ccyolotw='claude --dangerously-skip-permissions --rc -w --tmux'
alias ccauto='claude --permission-mode auto --rc'
alias ccautow='claude --permission-mode auto --rc -w'
alias ccautotw='claude --permission-mode auto --rc -w --tmux'
