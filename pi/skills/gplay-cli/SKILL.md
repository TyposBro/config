---
name: gplay-cli
description: Use Google Play Console CLI (`gplay`) for Android publishing workflows. Load when releasing Android APK/AAB to Play Store, inspecting tracks/rollouts/reviews/vitals/monetization/reports, syncing Play metadata, managing testers, or diagnosing Google Play API auth. Assumes `gplay` is installed and authenticated on this machine.
compatibility: macOS/Linux with gplay CLI installed; Google Play service account auth configured.
---

# gplay CLI

Use this skill for Google Play Console operations via the `gplay` command.

## Local setup

Installed via Homebrew:

```bash
brew tap tamtom/tap
brew install tamtom/tap/gplay
```

Current auth/profile is configured globally:

```bash
gplay auth status
gplay auth doctor
```

Known app package for this workspace:

```text
org.milliytechnology.spiko
```

## Safety rules

- Prefer read-only commands unless user explicitly asks to publish, upload, mutate metadata, reply to reviews, change rollout, or manage users.
- For commands that require edits, create a temporary edit and delete it after read-only inspection.
- Use `--dry-run` for write workflows when available before real changes.
- Never print or commit service account JSON contents.
- Use JSON output by default; pipe to `jq` for extraction.
- When creating edits for inspection, clean up with `gplay edits delete --confirm`.

## Auth diagnostics

```bash
gplay auth status
gplay auth doctor
gplay doctor --output json --pretty
```

## Read tracks safely

`tracks list` requires an edit ID. Pattern:

```bash
PKG="org.milliytechnology.spiko"
EDIT=$(gplay edits create --package "$PKG" | jq -r .id)
gplay tracks list --package "$PKG" --edit "$EDIT"
gplay edits delete --package "$PKG" --edit "$EDIT" --confirm
```

Known test result on this machine:

- production: `68 (2026.04.09)`, completed, versionCode `68`
- internal: `21 (2025.11.24)`, completed, versionCode `21`
- beta/alpha exist with no releases returned

## Common release workflows

Create complete internal release from an AAB:

```bash
gplay --dry-run release \
  --package org.milliytechnology.spiko \
  --track internal \
  --bundle path/to/app-release.aab
```

Real release after user approval:

```bash
gplay release \
  --package org.milliytechnology.spiko \
  --track internal \
  --bundle path/to/app-release.aab
```

Production staged rollout:

```bash
gplay --dry-run release \
  --package org.milliytechnology.spiko \
  --track production \
  --bundle path/to/app-release.aab \
  --rollout 10
```

Promote between tracks:

```bash
gplay --dry-run promote --package org.milliytechnology.spiko --from internal --to beta
```

Manage rollout:

```bash
gplay rollout update --package org.milliytechnology.spiko --track production --rollout 50
gplay rollout halt --package org.milliytechnology.spiko --track production
gplay rollout resume --package org.milliytechnology.spiko --track production
gplay rollout complete --package org.milliytechnology.spiko --track production
```

## Validation and preflight

Offline checks before upload:

```bash
gplay preflight --file path/to/app.aab
gplay bundles analyze --file path/to/app.aab --top-files 20
```

With stricter CI gate:

```bash
gplay preflight --file path/to/app.aab --max-size 100M --fail-on warning
```

## Store metadata

Export/import/diff Fastlane-style metadata:

```bash
gplay sync export-listings --package org.milliytechnology.spiko --dir ./fastlane/metadata/android
gplay sync diff-listings --package org.milliytechnology.spiko --dir ./fastlane/metadata/android
gplay sync import-listings --package org.milliytechnology.spiko --dir ./fastlane/metadata/android
```

Validate metadata/screenshots:

```bash
gplay validate listing --dir ./fastlane/metadata/android --locale en-US
gplay validate screenshots --dir ./fastlane/metadata/android/en-US/images
```

## Reviews, vitals, reports

```bash
gplay reviews list --package org.milliytechnology.spiko --paginate
gplay vitals crashes clusters --package org.milliytechnology.spiko
gplay vitals errors issues --package org.milliytechnology.spiko
```

Reports need the Play reports developer ID from the GCS URI `gs://pubsite_prod_rev_<id>/`, not necessarily the Play Console URL ID.

```bash
gplay reports financial list --developer <id>
gplay reports stats list --developer <id> --package org.milliytechnology.spiko
```

## Tester management

Tester commands also need an edit ID:

```bash
PKG="org.milliytechnology.spiko"
EDIT=$(gplay edits create --package "$PKG" | jq -r .id)
gplay testers list --package "$PKG" --edit "$EDIT" --track internal
gplay edits delete --package "$PKG" --edit "$EDIT" --confirm
```

## Troubleshooting

If `gplay apps list` fails with Reporting API not configured, verify app access with tracks instead:

```bash
PKG="org.milliytechnology.spiko"
EDIT=$(gplay edits create --package "$PKG" | jq -r .id)
gplay tracks list --package "$PKG" --edit "$EDIT"
gplay edits delete --package "$PKG" --edit "$EDIT" --confirm
```
