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

# Add each MCP server from the config file
echo "Adding cloudflare-doc MCP server..."
claude mcp add-json --scope user cloudflare-doc '{"command": "npx", "args": ["mcp-remote", "https://docs.mcp.cloudflare.com/sse"]}'

echo "Adding context7 MCP server..."
claude mcp add-json --scope user context7 '{"command": "npx", "args": ["-y", "@upstash/context7-mcp"]}'

echo "Adding browsermcp MCP server..."
claude mcp add-json --scope user browsermcp '{"command": "npx", "args": ["@browsermcp/mcp@latest"]}'

echo "MCP servers setup complete!"
echo "Run 'claude mcp list' to verify installation."