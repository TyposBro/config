# Ralph Loop Pi Extension

Automates milestone-by-milestone work without one huge rotting context.

## Commands

```txt
/ralph <plan.md> [--from N] [--to N] [--model provider/model] [--commit]
/ralph-status
```

Example:

```txt
/ralph specs/todo/03-instagram-reels-spark-plan.md --from 1 --to 8 --commit
```

## Behavior

For each milestone:

1. Start a fresh Pi subprocess/session with `--thinking medium`.
2. Instruct it to implement only that milestone and run focused checks.
3. Stop unless the final assistant message ends with `RALPH_STATUS: success`.
4. Start a fresh Pi subprocess/session with `--thinking xhigh`.
5. Instruct it to review/fix only that milestone and rerun checks.
6. Commit the reviewed milestone only when `--commit` is passed.
7. Continue to the next milestone.

Run state and raw JSONL logs are stored outside the repo by default:

```txt
~/.pi/agent/ralph-loop/<repo-name>-<repo-hash>/
```

Use `--state-dir <path>` to override.

## Useful options

```txt
--implement-thinking medium   # default
--review-thinking xhigh       # default
--model provider/model        # optional; omitted means Pi default model
--from N --to N               # milestone range
--to all                      # through last milestone
--commit                      # review stage commits passing milestone chunks
--dry-run                     # show selected milestones only
--no-extensions               # disable extensions in nested Pi subprocesses
--extra-pi-arg <arg>          # pass an extra arg to nested Pi; repeatable
```

## Why extension, not skill?

A skill can tell the model to work milestone-by-milestone, but it cannot reliably clear context or switch thinking levels by itself. This extension starts separate Pi subprocesses, so each implementation/review stage gets a clean context window and explicit thinking level.
