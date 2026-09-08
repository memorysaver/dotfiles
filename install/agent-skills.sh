#!/usr/bin/env bash
# Refresh global defaults and repair their links for every supported agent.
source "$(dirname "$0")/../lib/helpers.sh"
has npx || { warn "npx is required for global skills; install Node.js first"; exit 1; }
# User-selected global defaults; see docs/agent-skills-sources.md.
# Always run add: an existing canonical file does not prove every agent has its link.
for entry in herdrdev/herdr:herdr humanlayer/skills:show-me vercel-labs/agent-browser:agent-browser; do
  repo="${entry%%:*}" skill="${entry##*:}"
  if [ "$skill" = show-me ]; then
    repo="https://github.com/humanlayer/skills/tree/main/plugins/show-me/skills/show-me"
  fi
  npx --yes skills@1.5.20 add "$repo" --skill "$skill" -a '*' -g -y
done
# Remove the retired default only after the replacement installs successfully.
# In 1.5.20 remove rejects -a '*'; omitting -a removes from all agents.
if [ -e "$HOME/.agents/skills/i-have-adhd" ]; then
  npx --yes skills@1.5.20 remove i-have-adhd -g -y
fi
