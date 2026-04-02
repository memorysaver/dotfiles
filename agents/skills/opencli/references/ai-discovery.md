# AI Discovery Workflow: Find Public APIs on Any Website

When a site doesn't have a built-in adapter, OpenCLI's AI discovery commands can automatically find public endpoints, infer capabilities, and generate adapters.

## Quick Mode (One-Shot)

For simple cases — just want data from a site:

```bash
opencli generate https://example.com --goal "trending posts"
```

This runs explore + synthesize in one step. The `--goal` flag tells the AI what data you're after. After generation, the new commands appear in `opencli list`.

## Full Mode (Step-by-Step)

For more control over what gets discovered:

### Step 1: Explore

```bash
opencli explore https://example.com --site mysite
```

This discovers the site's APIs and generates structured artifacts:
- `manifest.json` — Site metadata (name, description, detected frameworks)
- `endpoints.json` — Discovered API endpoints with methods, params, response schemas
- `capabilities.json` — Inferred capabilities (search, list, detail, etc.)
- `auth.json` — Authentication strategy details (PUBLIC, COOKIE, HEADER, etc.)

### Step 2: Synthesize

```bash
opencli synthesize mysite
```

Converts the exploration artifacts into YAML adapter files. These are saved as new commands.

### Step 3: Use

```bash
opencli list                                  # See new commands
opencli mysite <command> --limit 5 -f json   # Run them
```

## Authentication Strategy Cascade

When you're not sure if an endpoint is public:

```bash
opencli cascade https://api.example.com/data
```

This auto-probes five tiers in order:

1. **PUBLIC** — Direct HTTP call, no auth. This is what we want for login-free gathering.
2. **COOKIE** — Reuses Chrome session cookies (requires browser bridge)
3. **HEADER** — Custom headers / API keys
4. **BROWSER** — Full browser automation
5. **CDP** — Chrome DevTools Protocol

The cascade stops at the first tier that works. If PUBLIC succeeds, you have a login-free endpoint.

## Tips for No-Login Discovery

- Target sites with known public APIs (REST/GraphQL endpoints that don't require auth tokens)
- Look for `/api/v1/`, `/api/public/`, or similar patterns in the site's network requests
- Many sites serve public data on their frontend that comes from unauthenticated API calls
- The `explore` command is good at finding these — check the generated `auth.json` to see which endpoints were classified as PUBLIC
- If `cascade` shows PUBLIC works, that endpoint is usable without login

## Workflow for Unknown Sites

```
1. opencli generate <url> --goal "<what you want>"
   └── If it works → done, use the generated commands
   └── If it fails or results are poor → continue to step 2

2. opencli explore <url> --site <name>
   └── Check auth.json for PUBLIC endpoints
   └── Check endpoints.json for available routes

3. opencli cascade <specific-endpoint-url>
   └── Confirms whether the endpoint is truly public

4. opencli synthesize <name>
   └── Generates adapters from exploration data

5. opencli <name> <command> --limit 5 -f json
   └── Test the generated commands
```

## Limitations

- AI discovery is best-effort — not all sites expose useful public APIs
- Some sites use client-side rendering with no public API at all
- Rate limiting may apply to discovered endpoints
- Generated adapters may need manual refinement for edge cases
