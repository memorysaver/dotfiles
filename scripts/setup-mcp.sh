#!/bin/bash

# Setup script for Claude Code MCP servers
# This script loads MCP server configurations from dotfiles

echo "Setting up Claude Code MCP servers..."

# Path to MCP config file in dotfiles
MCP_CONFIG="$HOME/.dotfiles/claude/mcp-servers.json"

if [ ! -f "$MCP_CONFIG" ]; then
    echo "Error: MCP config file not found at $MCP_CONFIG"
    exit 1
fi

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed. Please install jq first."
    exit 1
fi

# Loop through each MCP server in the config file
jq -r '.mcpServers | to_entries[] | @json' "$MCP_CONFIG" | while read -r server; do
    name=$(echo "$server" | jq -r '.key')
    config=$(echo "$server" | jq -c '.value')
    
    echo "Adding $name MCP server..."
    claude mcp add-json --scope user "$name" "$config"
done

echo "MCP servers setup complete!"
echo "Run 'claude mcp list' to verify installation."