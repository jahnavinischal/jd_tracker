# job-tracker

A daily pipeline that watches company career sites and reports data-science/AI
postings in India (and remote) as soon as they open. It reads the same JSON
endpoints the companies' own careers pages call, so a role shows up as soon as
it is published rather than whenever an aggregator gets round to crawling it.

```
config.yaml --> fetch --> normalize --> diff --> notify
                  |          |            |
              raw/*.json   Job         data/jobs.db
```

## Quick start

```bash
uv run python -m tracker.run --preview   # what matches your filters RIGHT NOW
uv run python -m tracker.run             # the daily run: reports only what's new
uv run python -m tracker.run --digest 7  # what opened/closed in the last 7 days
```

`--preview` ignores the database and lists every currently-open matching role.
Use it to tune filters. The database is already seeded, so the plain run reports
only genuinely new postings from here on.

As of the last run: **451 matching open roles out of 9,850 scanned.**

## Company coverage

| Company | ATS | Status |
|---|---|---|
| Amazon | `amazonjobs` | working — 2,106 India roles |
| NVIDIA | `workday` | working — 2,523 (search-union, see below) |
| Genpact | `workday` | working — 1,942 |
| The Hartford | `workday` | working — 237, incl. India GCC |
| Chubb | `oracle` | working — 754 |
| Uber | `oracle` | working — 805 |
| Netflix | `eightfold` | working — 396 |
| Meesho | `lever` | working — 53 |
| Microsoft | `microsoft` | **unverified** — TLS failure in the build environment only |
| Stripe / Ramp / Spotify | greenhouse / ashby / lever | working (from the earlier setup) |

### Microsoft

Microsoft's Eightfold board (`apply.careers.microsoft.com`) rejects API calls
with `Not authorized for PCSX`, so the adapter uses the `gcsservices` endpoint
its careers SPA calls. That host failed TLS verification from the build
environment (hostname mismatch), which looks environmental rather than a
property of the API. Confirm from your machine:

```bash
uv run python -m tracker.run --only Microsoft --dry-run
```

If it still fails, the fallback is a Distill.io watcher on
`jobs.careers.microsoft.com/global/en/search?lc=India`.

### Companies still unresolved

| Company | What it runs | Why it isn't wired up |
|---|---|---|
| Google | custom | job data only inside `AF_initDataCallback` blobs in 1.2 MB of HTML |
| Apple | Phenom | server-rendered HTML only; no JSON endpoint found |
| Meta | custom GraphQL | needs a `doc_id` that rotates |
| Cognizant | custom | no public JSON endpoint found |
| HCLTech | SuccessFactors | server-rendered HTML only |
| Myntra | custom SPA | careers page is an empty shell; no API found |
| Infosys | — | HTTP 403, WAF blocks non-browser clients |
| IndiGo | — | HTTP 403, same |

Three options for these, cheapest first:

1. **Distill.io / Visualping** watchers on each careers URL — zero code, alerts
   on page change. Best for Infosys and IndiGo, where the block is deliberate.
2. **HTML-parsing adapters** for Google, Apple and HCLTech. All three
   server-render their listings, so this is very doable — just more fragile than
   a JSON feed, and it breaks whenever they restyle.
3. **LinkedIn job alerts** set to the company with "Instant" frequency, as a
   backstop for all eight.

## Your filter profile

Tuned for data science / AI, ~4 years' experience (1 internship + 3 working),
India metros plus remote. Two rule styles, usable together:

```yaml
title_include:        [data scien, machine learning, applied scientist, ...]
title_include_regex:  ['\bai\b', '\bml\b', '\bllm[s]?\b']   # word boundaries
title_exclude:        [staff, principal, director, manager, intern, ...]
title_exclude_regex:  ['\bL[6-9]\b', '\bIV\b|\bV\b|\bVI\b'] # seniority markers
location_include:     [india, delhi, noida, gurgaon, bengaluru, ..., remote]
```

Short tokens **must** use the regex form: the substring `ai` also matches
"m**ai**ntenance" and "ret**ai**l", and `ml` matches "ht**ml**". Adding the
regex rules took NVIDIA from 4 matches to 18, because titles like
"AI Software Engineer" match no spelled-out include term.

A posting must match a title rule **and** a location rule. Filters apply at
notification time only — everything is stored regardless, so you can change
these and re-run `--digest` over full history. Filtered-out postings are counted
(`N hidden by filters`) so an over-aggressive filter is visible, not silent.

`senior` is deliberately **not** excluded: at 4 years you are in range for
"Senior Data Scientist" in India, which typically means 3–6 years. Add it to
`title_exclude` if you disagree.

### Known filter tradeoff: US-remote noise

`remote` in `location_include` means "remote anywhere", as you asked — but it
also admits roles like Netflix's "Remote, United States", which need US work
authorization. That is most of Netflix's 28 matches. To drop them:

```yaml
location_exclude:
  - "remote, united states"
  - "united states - remote"
  - "us remote"
```

Left out by default, since you said remote anywhere in the world.

## Per-company tuning

Any company may override individual filter keys:

```yaml
  - name: Meesho
    ats: lever
    slug: meesho
    filters:
      location_include: []    # India-only company; no need to filter
```

**Workday's 2000-posting cap.** A single Workday result set is capped at 2000,
which silently hid NVIDIA's India roles. Setting `search: [...]` fetches each
term separately and unions the results, keeping every request under the cap:

```yaml
  - name: NVIDIA
    ats: workday
    search: ["data scientist", "machine learning", "analytics", "AI"]
```

## Adding a company

Edit `config.yaml` — no code change needed. To identify a company's ATS: open
its careers page, DevTools → Network → filter XHR, and see which domain serves
the job list.

| `ats` | endpoint | required config |
|---|---|---|
| `greenhouse` | `boards-api.greenhouse.io/v1/boards/{slug}/jobs` | `slug` |
| `lever` | `api.lever.co/v0/postings/{slug}` | `slug` |
| `ashby` | `api.ashbyhq.com/posting-api/job-board/{slug}` | `slug` |
| `smartrecruiters` | `api.smartrecruiters.com/v1/companies/{slug}/postings` | `slug` (case-sensitive) |
| `workable` | `apply.workable.com/api/v3/accounts/{slug}/jobs` | `slug` |
| `workday` | `{slug}.{host}.myworkdayjobs.com/wday/cxs/...` | `slug`, `host`, `site` |
| `oracle` | `{host}/hcmRestApi/.../recruitingCEJobRequisitions` | `host`, `site`, `site_number` |
| `eightfold` | `{host}/api/apply/v2/jobs` | `host`, `domain` |
| `amazonjobs` | `www.amazon.jobs/en/search.json` | — (`countries` recommended) |
| `microsoft` | `gcsservices.careers.microsoft.com/search/api/v1/search` | — (`locations` recommended) |

Missing required keys fail at config load, before any network call.

A wrong slug usually returns HTTP 200 with zero jobs — indistinguishable from an
empty board — so the run prints `[warn] ... returned 0 postings` to flag it.

## Notifications

Console is always on. Telegram switches on when both env vars are present:

```bash
export TELEGRAM_BOT_TOKEN=...   # @BotFather -> /newbot
export TELEGRAM_CHAT_ID=...     # api.telegram.org/bot<TOKEN>/getUpdates
```

The snapshot is committed **only after delivery succeeds**. A dead webhook rolls
the run back so the batch is re-reported next run instead of being lost
(verified: a failed send leaves the posting unrecorded and the next run reports
it again).

## Daily schedule (Windows Task Scheduler)

`run.cmd` cd's to this folder and appends to `logs/run.log`.

```
Program/script:  C:\Users\jahna\Downloads\agentic\run.cmd
Start in:        C:\Users\jahna\Downloads\agentic
```

Check "Run whether user is logged on or not". A missing *Start in* is the usual
cause of a task that reports success but does nothing.

A full run takes a few minutes and ~10k postings of traffic, so once a day is
sensible. If you want to be early on competitive roles — some close within 48
hours — every 2–4 hours is fine; only the trigger changes. Don't go below ~10
minutes: these endpoints are public but undocumented, and the point is to stay a
polite client.

## Commands

| command | what it does |
|---|---|
| `--preview` | every open posting matching your filters, ignoring the diff |
| `--digest 7` | first seen in the last 7 days, plus what closed |
| `--dry-run` | fetch and diff, write nothing |
| `--only Amazon` | limit to one company (repeatable) |
| `--show-closed` | include closed roles in the report |
| `--no-notify` | print instead of sending |
| `--no-raw` | skip archiving raw payloads |

## Data

- `data/jobs.db` — `jobs` (current snapshot), `events` (append-only
  new/closed/changed/repost log), `applications` (your own pipeline), `meta`.
- `raw/{ats}-{id}/{date}.json` — untouched payloads, written before parsing.
  When an ATS changes shape, this is what you debug against.

The `applications` table exists but has no CLI yet — it's there so watching and
tracking can share one database.

## Design notes

- **Pagination differs per ATS and lies in two places.** Workday reports `total`
  on the first page only (later pages say `0`); Eightfold silently caps a page
  at 10 however large `num` is. Both bugs looked like "the company only has 40
  jobs". Every paginated adapter now takes the total from the first page and
  stops on a short page.
- **Reposts.** A posting whose `company|title|location` matches an existing row
  is logged as `repost`, not announced as new — some ATSs re-list the same role
  under a fresh id.
- **Changes** are detected by hashing only title/location/department/url;
  hashing the raw payload would flag an edit on every fetch, since the feeds
  carry churning timestamps.
- **Partial failure.** Each company is fetched independently, so one company's
  500 cannot hide another's new postings, and a failed fetch never reports that
  company's roles as closed. Failures appear in the notification, so silence is
  never mistaken for "nothing new".
- **`first_seen` is preserved** across runs, so you can ask how long a role has
  been open.

## Tests

```bash
uv run python -m tests.test_pipeline
```

26 offline tests, no network: all ten normalizers against recorded payload
shapes, both filter styles, and the diff/seed/repost/rollback logic.

Greenhouse, Lever, Ashby, SmartRecruiters, Workday, Oracle, Eightfold and
amazon.jobs are additionally verified against live boards. Workable's request
shape is confirmed but every account probed had zero open roles, so its
`normalize` is fixture-only; Microsoft is unverified (see above).


# to run on on terminal
serve.cmd
or
uv run python -m tracker.web
