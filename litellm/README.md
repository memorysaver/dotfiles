# LiteLLM Proxy Setup

This directory contains template files for setting up LiteLLM proxy to route Anthropic Claude requests through OpenRouter models with wildcard routing support.

## Files

- `.env.template` - Environment variables template (copy to `.env` and add your API key)
- `config.yaml` - Wildcard routing configuration (supports all OpenRouter models)
- `README.md` - This documentation file

## Setup

### Method 1: Using uvx (Recommended)

1. **Setup environment:**
   ```bash
   source ~/.zshrc  # Reload shell to get new functions
   ```

2. **Start LiteLLM:**
   ```bash
   litellm-start
   ```
   
   On first run, it will create `~/.litellm/.env` and prompt you to add your OpenRouter API key.

3. **Add your OpenRouter API key:**
   ```bash
   # Get your key from https://openrouter.ai/keys
   nano ~/.litellm/.env
   # Change: OPENROUTER_API_KEY=your_openrouter_api_key_here
   ```

4. **Start again:**
   ```bash
   litellm-start
   ```

5. **Stop LiteLLM:**
   ```bash
   litellm-stop
   ```

### Background Operation

LiteLLM runs in a background tmux session named `litellm-server`:

- **View logs:** `tmux attach -t litellm-server`
- **Detach from logs:** Press `Ctrl+B`, then `D`
- **Server runs on:** `http://localhost:4000`

## Configuration

### Wildcard Routing

The configuration uses wildcard routing to support all OpenRouter models:

- `anthropic/*` → Routes to `openrouter/*` (for Claude Code requests)
- `openrouter/*` → Routes to `openrouter/*` (for direct OpenRouter requests)

This allows you to use any OpenRouter model by specifying it in your requests:
- `openrouter/anthropic/claude-3-5-sonnet`
- `openrouter/meta-llama/llama-3.2-90b-vision-instruct`
- `openrouter/google/gemini-2.0-flash-thinking-exp`
- `openrouter/qwen/qwen3-coder` (default)

### Environment Variables

- `OPENROUTER_API_KEY` - Your OpenRouter API key (required)
- `LITELLM_PORT` - Port for LiteLLM proxy (default: 4000)
- `LITELLM_LOG` - Log level (default: INFO)

## Usage with Claude Code

### Quick Start Commands

1. **Direct Claude Code with LiteLLM:**
   ```bash
   cclitellm                                    # Uses default qwen3-coder
   cclitellm openrouter/anthropic/claude-3-5-sonnet   # Use specific model
   ```

2. **Development Environment (tmux):**
   ```bash
   cclitedev                                    # Default model in tmux
   cclitedev openrouter/meta-llama/llama-3.2-90b-vision-instruct  # Specific model
   ```

### Manual Configuration

If you need manual setup:

```bash
export ANTHROPIC_AUTH_TOKEN="sk-1234"
export ANTHROPIC_BASE_URL="http://localhost:4000"
export ANTHROPIC_MODEL="openrouter/your-preferred-model"
```

## Available Functions

- `litellm-start` - Start LiteLLM proxy in background tmux session
- `litellm-stop` - Stop LiteLLM proxy and tmux session
- `cclitellm [model]` - Launch Claude Code with LiteLLM (auto-starts proxy if needed)
- `cclitedev [model] [session]` - Launch Claude Code in tmux development environment

## Troubleshooting

1. **Permission issues:** Make sure uvx is installed and in your PATH
2. **Port conflicts:** Change `LITELLM_PORT` in `.env` if port 4000 is busy
3. **API key issues:** Verify your OpenRouter API key is valid and has credits
4. **Model errors:** Check OpenRouter model availability and pricing
5. **View server logs:** `tmux attach -t litellm-server` to see real-time logs
6. **Restart server:** `litellm-stop && litellm-start` to restart with new config

## Model Examples

Popular OpenRouter models you can use:

### Anthropic Models
- `openrouter/anthropic/claude-3-5-sonnet`
- `openrouter/anthropic/claude-3-5-haiku`
- `openrouter/anthropic/claude-3-opus`

### Meta Llama Models  
- `openrouter/meta-llama/llama-3.2-90b-vision-instruct`
- `openrouter/meta-llama/llama-3.1-405b-instruct`

### Google Models
- `openrouter/google/gemini-2.0-flash-thinking-exp`
- `openrouter/google/gemini-pro-1.5`

### Coding Models
- `openrouter/qwen/qwen3-coder` (default, good balance of speed/quality)
- `openrouter/deepseek/deepseek-coder`

See [OpenRouter Models](https://openrouter.ai/models) for the complete list.