---
name: gplay-cli
description: Use Google Play Console CLI (gplay) for Spiko Android publishing/reviews/tracks/releases. Load when user asks about Google Play, Play Console, Android release, app reviews, store listings, Play tracks, rollout, reports, vitals, testers, or gplay commands. Default local setup uses package org.milliytechnology.spiko and service-account profile default.
---

# gplay CLI Skill

Use `gplay` to manage Google Play Console from terminal. Prefer JSON output for scripts; use `--pretty` for human inspection.

## Local Setup

Installed binary:

```bash
export PATH="$HOME/.local/bin:$PATH"
gplay version
```

Configured files:

- Config: `~/.gplay/config.json`
- Service account key: `~/.gplay/play-console-cli.json`
- Default profile: `default`
- Default app package: `org.milliytechnology.spiko`
- GCP project: `multilevel-5454`
- Service account: `play-console-cli@multilevel-5454.iam.gserviceaccount.com`

Health check:

```bash
gplay doctor --output json --pretty
```

## Safety Rules

- Never print or commit `~/.gplay/play-console-cli.json`.
- For write operations, prefer `--dry-run` first unless user explicitly asks to publish/change.
- Release operations can affect Play Store users. Confirm package, track, artifact path, rollout percent, and release notes before commit.
- If an edit is created just for reading tracks/listings, delete it afterward if possible.

## Common Commands

Reviews:

```bash
gplay reviews list --package org.milliytechnology.spiko --paginate --pretty
gplay reviews get --package org.milliytechnology.spiko --review-id <id> --pretty
gplay reviews reply --package org.milliytechnology.spiko --review-id <id> --text "<reply>"
```

Tracks require an edit:

```bash
EDIT=$(gplay edits create --package org.milliytechnology.spiko | jq -r .id)
gplay tracks list --package org.milliytechnology.spiko --edit "$EDIT" --pretty
gplay edits delete --package org.milliytechnology.spiko --edit "$EDIT" --confirm
```

One-command release:

```bash
gplay --dry-run release --package org.milliytechnology.spiko --track internal --bundle app-release.aab
# after verification:
gplay release --package org.milliytechnology.spiko --track internal --bundle app-release.aab
```

Rollout:

```bash
gplay rollout update --package org.milliytechnology.spiko --track production --rollout 10
gplay rollout halt --package org.milliytechnology.spiko --track production
gplay rollout resume --package org.milliytechnology.spiko --track production
gplay rollout complete --package org.milliytechnology.spiko --track production
```

Listings and metadata:

```bash
EDIT=$(gplay edits create --package org.milliytechnology.spiko | jq -r .id)
gplay listings list --package org.milliytechnology.spiko --edit "$EDIT" --pretty
gplay details get --package org.milliytechnology.spiko --edit "$EDIT" --pretty
gplay edits delete --package org.milliytechnology.spiko --edit "$EDIT" --confirm
```

Vitals:

```bash
gplay vitals crashes clusters --package org.milliytechnology.spiko --pretty
gplay vitals errors issues --package org.milliytechnology.spiko --pretty
gplay vitals performance startup --package org.milliytechnology.spiko --pretty
```

Reports:

```bash
gplay reports financial list --developer <report-developer-id> --pretty
gplay reports stats list --developer <report-developer-id> --package org.milliytechnology.spiko --pretty
```

## Sentiment Workflow

1. Fetch reviews:

```bash
gplay reviews list --package org.milliytechnology.spiko --paginate --pretty
```

2. Extract star rating, text, language, app version, device, timestamp.
3. Summarize:
   - avg rating
   - rating distribution
   - positive/negative/neutral count
   - repeated themes
   - angry users needing reply
   - product recommendations
4. For Uzbek reviews, translate key quotes to English.

## Docs

Upstream project: `https://github.com/tamtom/play-console-cli`

Useful upstream docs if cloned:

- `README.md` — command overview
- `GPLAY.md` — generated CLI command docs
- `Agents.md` — agent guidance

## Full Capability Map

When user asks what gplay can do, mention these API areas. If exact flags are unknown, run `gplay <command> --help` or inspect upstream `GPLAY.md`.

### Publishing / release management

- `edits` — create/list/validate/commit/delete Play edits.
- `bundles` — upload/analyze/compare AABs.
- `apks` — upload APKs.
- `tracks` — list/get/update track releases.
- `release` — one-command upload + track update + commit.
- `publish` — canonical release workflows.
- `promote` — move release between tracks.
- `rollout` — update/halt/resume/complete staged rollout.
- `generated-apks` — download device-specific APKs from uploaded bundles.
- `deobfuscation` — upload ProGuard/R8 mapping files.
- `expansion` — OBB expansion file management.
- `system-apks` — system image APK creation.
- `recovery` — app recovery actions.

### Store presence / metadata

- `listings` — localized title, short/full descriptions, video.
- `details` — app contact/default language/category details.
- `images` — screenshots, feature graphics, icons, media.
- `metadata` — file-based metadata pull/push/validate.
- `sync` — Fastlane-style metadata export/import/diff.
- `validate` — listing/screenshot/bundle/release readiness checks.
- `data-safety` — data safety declarations.
- `device-tiers` — device tier config management.
- `availability` — country availability for tracks.
- `migrate` — migrate from other metadata formats/tools if present in this build.

### Reviews / user feedback

- `reviews` — list/get/reply to reviews.
- Use for sentiment analysis, bug clustering, reply drafting, app-version regression checks.

### Vitals / quality / diagnostics

- `vitals` — crashes, ANRs/errors, startup, rendering, battery metrics.
- `preflight` — offline APK/AAB compliance/hygiene scan.
- `status` — release-health snapshot.
- `doctor` — local auth/config/network check.
- `audit` — local gplay invocation log.
- `quota` — API quota usage derived from audit log.

### Monetization / products

- `iap` — managed in-app products.
- `subscriptions` — subscription products.
- `baseplans` — subscription base plans.
- `offers` — subscription offers/trials/intro pricing.
- `onetimeproducts` — one-time products.
- `purchase-options` — one-time product purchase options.
- `otp-offers` — one-time product offer management.
- `pricing` — regional price conversion.
- `external-transactions` — EU/external transaction reporting.

### Purchases / orders

- `purchases` — verify/acknowledge product and subscription purchase tokens.
- `orders` — look up/refund orders.

### Testing / distribution

- `testers` — list/update closed-track tester emails.
- `internal-sharing` — upload AAB/APK for internal app sharing.

### Team / permissions

- `users` — developer account users CRUD/invites.
- `grants` — per-app permission grants CRUD.

### Reports / notifications / integrations

- `reports` — financial/statistics report list/download from GCS buckets.
- `rtdn` — Real-Time Developer Notifications setup/status/decode.
- `notify` — send Slack/Discord/generic webhook notifications.
- `workflow` — run multi-step automation workflows.
- `web` — open Play Console pages.
- `apps` — list/manage accessible apps where supported by enabled APIs.

## Discovery Pattern for Unknown Commands

Use these before saying a feature is unavailable:

```bash
gplay --help
gplay <command> --help
gplay <command> <subcommand> --help
```

For commands needing an edit:

```bash
EDIT=$(gplay edits create --package org.milliytechnology.spiko | jq -r .id)
# run read/list/get command with --edit "$EDIT"
gplay edits delete --package org.milliytechnology.spiko --edit "$EDIT" --confirm
```
