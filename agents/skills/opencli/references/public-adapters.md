# Public Adapters: Complete Reference

All adapters below are verified `[public]` via `opencli list` — no login, no browser, no credentials needed.

## Table of Contents
1. [HackerNews](#hackernews)
2. [Stack Overflow](#stack-overflow)
3. [arXiv](#arxiv)
4. [Wikipedia](#wikipedia)
5. [Dev.to](#devto)
6. [BBC News](#bbc-news)
7. [Lobsters](#lobsters)
8. [Dictionary](#dictionary)
9. [Steam](#steam)
10. [Hugging Face](#hugging-face)
11. [Apple Podcasts](#apple-podcasts)
12. [Sina Finance](#sina-finance)
13. [Xiaoyuzhou](#xiaoyuzhou)
14. [paperreview.ai](#paperreviewai)
15. [Bluesky](#bluesky)
16. [Google](#google)
17. [IMDb](#imdb)
18. [Bloomberg](#bloomberg)
19. [Product Hunt](#product-hunt)
20. [V2EX](#v2ex)
21. [WeRead](#weread)
22. [Substack](#substack)
23. [Tieba](#tieba)
24. [Ctrip](#ctrip)

---

## HackerNews

Tech news, discussions, job posts.

```bash
opencli hackernews top --limit 10 -f json       # Top stories
opencli hackernews new --limit 10 -f json        # Newest stories
opencli hackernews best --limit 10 -f json       # Best stories
opencli hackernews ask --limit 10 -f json        # Ask HN threads
opencli hackernews show --limit 10 -f json       # Show HN posts
opencli hackernews jobs --limit 10 -f json       # Job postings
opencli hackernews search "rust" --limit 5 -f json  # Search
opencli hackernews user "pg" -f json             # User profile
```

**Columns:** title, url, score, author, comments, time

---

## Stack Overflow

Programming Q&A.

```bash
opencli stackoverflow hot --limit 10 -f json         # Hot questions
opencli stackoverflow search "async rust" --limit 5 -f json  # Search
opencli stackoverflow bounties --limit 5 -f json     # Open bounties
opencli stackoverflow unanswered --limit 5 -f json   # Unanswered questions
```

**Columns:** title, url, score, answers, tags, views

---

## arXiv

Academic research papers. **Note:** The arXiv API can return HTTP 429 (rate limit) if called too frequently. Wait a few seconds between requests.

```bash
opencli arxiv search "transformer architecture" --limit 5 -f json  # Search papers
opencli arxiv paper 2301.00001 -f json                              # Get specific paper
```

**Columns:** title, authors, abstract, url, published, categories

---

## Wikipedia

General knowledge encyclopedia.

```bash
opencli wikipedia search "quantum computing" --limit 5 -f json  # Search articles
opencli wikipedia summary "Quantum computing" -f json            # Article summary
opencli wikipedia random -f json                                  # Random article
opencli wikipedia trending --limit 10 -f json                    # Most-read (yesterday)
```

**Columns:** title, url, summary/extract

---

## Dev.to

Developer blog posts and articles.

```bash
opencli devto top --limit 10 -f json           # Top posts
opencli devto tag "javascript" --limit 5 -f json  # Posts by tag
opencli devto user "ben" --limit 5 -f json     # Posts by user
```

**Columns:** title, url, author, reactions, comments, tags, published

---

## BBC News

World news headlines (RSS).

```bash
opencli bbc news --limit 10 -f json
```

**Columns:** title, url, summary, published

---

## Lobsters

Tech link aggregator (similar to HN, more niche).

```bash
opencli lobsters hot --limit 10 -f json            # Hot stories
opencli lobsters newest --limit 10 -f json         # Newest
opencli lobsters active --limit 10 -f json         # Most active discussions
opencli lobsters tag "rust" --limit 5 -f json      # By tag
```

**Columns:** title, url, score, author, comments, tags

---

## Dictionary

Word definitions, synonyms, usage.

```bash
opencli dictionary search "ephemeral" -f json      # Definition
opencli dictionary synonyms "happy" -f json        # Synonyms
opencli dictionary examples "serendipity" -f json  # Usage examples
```

**Columns:** word, definition, part_of_speech, synonyms, example

---

## Steam

Gaming marketplace data.

```bash
opencli steam top-sellers --limit 10 -f json
```

**Columns:** title, url, price, discount, rating

---

## Hugging Face

Trending AI/ML papers.

```bash
opencli huggingface top --limit 10 -f json
```

---

## Apple Podcasts

Podcast discovery.

```bash
opencli apple-podcasts search "tech" --limit 5 -f json    # Search podcasts
opencli apple-podcasts top --limit 10 -f json              # Top podcasts
opencli apple-podcasts episodes <podcast-id> -f json       # Episode list
```

---

## Sina Finance

Chinese financial news AND stock quotes (A-shares, HK, US markets).

```bash
opencli sina-finance news --limit 10 -f json       # 7x24 real-time financial news
opencli sina-finance stock AAPL -f json            # US stock quote
opencli sina-finance stock 600519 -f json          # A-share quote (Moutai)
```

---

## Xiaoyuzhou

Chinese podcast platform.

```bash
opencli xiaoyuzhou podcast <id> -f json              # Podcast details
opencli xiaoyuzhou podcast-episodes <id> -f json     # Episodes (up to 15)
opencli xiaoyuzhou episode <id> -f json              # Single episode
```

---

## paperreview.ai

Academic paper peer review.

```bash
opencli paperreview submit <paper-url> -f json       # Submit for review
opencli paperreview review <token> -f json            # Get review
opencli paperreview feedback <token> -f json          # Get feedback
```

---

## Bluesky

Decentralized social network — fully public, no login needed.

```bash
opencli bluesky trending -f json                           # Trending topics
opencli bluesky user <handle> -f json                      # User's recent posts
opencli bluesky search "AI" -f json                        # Search users
opencli bluesky thread <post-url> -f json                  # Post thread with replies
opencli bluesky profile <handle> -f json                   # User profile
opencli bluesky followers <handle> -f json                 # User's followers
opencli bluesky following <handle> -f json                 # Who user follows
opencli bluesky starter-packs <handle> -f json             # Starter packs
opencli bluesky feeds -f json                              # Popular feed generators
```

---

## Google

Search, news, trends, and autocomplete.

```bash
opencli google news "AI" --limit 5 -f json       # Google News
opencli google search "query" --limit 5 -f json  # Web search
opencli google suggest "query" -f json            # Autocomplete suggestions
opencli google trends "AI" -f json               # Daily trending searches
```

---

## IMDb

Movies, TV shows, people.

```bash
opencli imdb search "inception" --limit 5 -f json    # Search
opencli imdb title tt1375666 -f json                  # Title details
opencli imdb top --limit 10 -f json                   # Top 250
opencli imdb trending --limit 10 -f json              # Most Popular
opencli imdb person nm0000151 -f json                 # Person info
opencli imdb reviews tt1375666 --limit 5 -f json      # User reviews
```

---

## Bloomberg

Financial news via RSS feeds — all public.

```bash
opencli bloomberg main --limit 10 -f json           # Top stories
opencli bloomberg markets -f json                    # Markets
opencli bloomberg economics -f json                  # Economics
opencli bloomberg tech -f json                       # Technology
opencli bloomberg politics -f json                   # Politics
opencli bloomberg opinions -f json                   # Opinions
opencli bloomberg industries -f json                 # Industries
opencli bloomberg businessweek -f json               # Businessweek
opencli bloomberg feeds -f json                      # List all RSS feed aliases
```

**Note:** `bloomberg news` (reading full articles) requires `[cookie]` login.

---

## Product Hunt

Product launches and discoveries.

```bash
opencli product-hunt posts --limit 10 -f json       # Latest launches
opencli product-hunt today -f json                   # Today's launches
```

---

## V2EX

Chinese developer community / tech forum.

```bash
opencli v2ex hot -f json                    # Hot topics
opencli v2ex latest -f json                 # Latest topics
opencli v2ex node "python" -f json          # Topics in a node
opencli v2ex topic <id> -f json             # Topic details + replies
opencli v2ex member <username> -f json      # User profile
opencli v2ex replies <id> -f json           # Topic replies
opencli v2ex user <username> -f json        # User's posts
opencli v2ex nodes -f json                  # All nodes list
```

---

## WeRead

Book rankings and search (Tencent WeRead).

```bash
opencli weread ranking -f json              # Book rankings
opencli weread search "design patterns" -f json  # Search books
```

---

## Substack

Newsletter search.

```bash
opencli substack search "technology" -f json
```

---

## Tieba

Baidu Tieba hot topics.

```bash
opencli tieba hot -f json
```

---

## Ctrip

Travel destination/hotel search (Chinese travel platform).

```bash
opencli ctrip search "Tokyo" -f json
```

---

## NOT Public (Common Misconceptions)

These adapters are **NOT** available without browser login:

| Adapter | Strategy | Why Not Public |
|---------|----------|---------------|
| `barchart` | `[cookie]` | All commands require browser session |
| `bilibili` | `[cookie]` | Chinese video platform, needs login |
| `douban` | `[cookie]` | Chinese review site, needs login |
| `zhihu` | `[cookie]`/`[intercept]` | Chinese Q&A, needs login |
| `weibo` | `[cookie]` | Chinese social media, needs login |
| `xiaohongshu` | `[cookie]` | Chinese social commerce, needs login |
| `twitter`/`x` | `[cookie]` | Requires authenticated session |

There is also **no `yahoo-finance` adapter** in opencli. For stock quotes, use `sina-finance stock <TICKER>` instead.
