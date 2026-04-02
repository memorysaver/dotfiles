# Creating Custom YAML Adapters

When a site has a public JSON API but no built-in adapter, you can write a simple YAML file to add it as an OpenCLI command. Zero dependencies, no build step.

## Where to Put It

Save YAML adapters to the plugins directory:

```
~/.opencli/plugins/<site-name>/<command>.yaml
```

Example: `~/.opencli/plugins/jsonplaceholder/posts.yaml`

The adapter is immediately available after saving — no restart needed.

## Basic Structure

```yaml
site: jsonplaceholder
name: posts
description: List posts from JSONPlaceholder
domain: jsonplaceholder.typicode.com
strategy: public
browser: false
args:
  - name: limit
    type: int
    default: 10
    help: Maximum number of posts
pipeline:
  - fetch:
      url: https://jsonplaceholder.typicode.com/posts
  - limit: ${{ args.limit }}
  - map:
      id: ${{ item.id }}
      title: ${{ item.title }}
      body: ${{ item.body }}
columns: [id, title, body]
```

Usage: `opencli jsonplaceholder posts --limit 5 -f json`

## Required Fields

| Field | Description |
|-------|-------------|
| `site` | Site identifier (used as CLI namespace) |
| `name` | Command name (used as subcommand) |
| `description` | Help text shown in `opencli list` |
| `domain` | Target domain |
| `strategy` | Auth strategy — use `public` for no-login |
| `browser` | Set to `false` for public API adapters |
| `args` | CLI argument definitions |
| `pipeline` | Data processing steps |
| `columns` | Output column names |

## Pipeline Steps

### fetch

Retrieves data from a URL:

```yaml
- fetch:
    url: https://api.example.com/data?limit=${{ args.limit }}
    headers:
      Accept: application/json
```

Template expressions (`${{ }}`) are evaluated at runtime.

### map

Transforms each item in the result array:

```yaml
- map:
    title: ${{ item.title }}
    url: ${{ item.url }}
    score: ${{ item.score }}
    rank: ${{ index }}          # Zero-based position
```

### limit

Truncates results:

```yaml
- limit: ${{ args.limit }}
```

### filter

Conditionally includes items:

```yaml
- filter: ${{ item.score > 10 }}
```

### download

Saves media files:

```yaml
- download:
    url: ${{ item.image_url }}
    filename: ${{ item.title | sanitize }}.jpg
```

## Template Expressions

| Pattern | Description |
|---------|-------------|
| `${{ args.limit }}` | CLI argument value |
| `${{ item.title }}` | Current item's field |
| `${{ item.nested.field }}` | Nested field access |
| `${{ index }}` | Zero-based position in array |
| `${{ item.name \| sanitize }}` | Pipe filter for sanitization |

## Arguments

```yaml
args:
  - name: query           # Positional argument (required by default)
    required: true
    help: Search query
  - name: limit           # Named flag (--limit)
    type: int
    default: 10
    help: Max results
  - name: sort            # Named flag (--sort)
    type: string
    default: "hot"
    help: Sort order
```

**Design rule:** Keep the primary subject as a positional argument (e.g., `opencli mysite search "query"`). Use named flags only for optional modifiers.

## Complete Example: Reddit Public JSON API

```yaml
site: reddit
name: hot
description: Get hot posts from a subreddit
domain: www.reddit.com
strategy: public
browser: false
args:
  - name: subreddit
    required: true
    help: Subreddit name (without r/)
  - name: limit
    type: int
    default: 10
    help: Number of posts
pipeline:
  - fetch:
      url: https://www.reddit.com/r/${{ args.subreddit }}/hot.json?limit=${{ args.limit }}
  - map:
      title: ${{ item.data.title }}
      url: https://reddit.com${{ item.data.permalink }}
      score: ${{ item.data.score }}
      author: ${{ item.data.author }}
      comments: ${{ item.data.num_comments }}
columns: [title, score, author, comments, url]
```

Usage: `opencli reddit hot programming --limit 5 -f json`

## Tips

- Always set `strategy: public` and `browser: false` for no-login adapters
- Test the API URL in your browser or with `curl` first to verify it returns JSON
- Use `opencli <site> <command> -v` for verbose debugging if the pipeline fails
- If the API returns nested data (e.g., `{"data": {"children": [...]}}`), you may need to adjust the fetch or use a TypeScript adapter instead
- Keep expressions readable — if logic gets complex, switch to a TypeScript adapter
- Add fallback values for optional fields that may be missing upstream
