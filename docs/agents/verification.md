# Verification — bubbles_sheet

`tool/harness/verify <fast|normal|full>` is the only thing that decides whether this
repo's changes pass. An agent's judgement is not verification; the exit code and the
`verify.json` it writes are.

The checks below are this repository's actual commands (there is no CI workflow and no
Makefile here to inherit them from) — see `AGENTS.md` for where each one came from.

## Tiers

| Check | Command | fast | normal | full |
|---|---|:--:|:--:|:--:|
| `format` | `dart format --output=none --set-exit-if-changed .` | ✓ | ✓ | ✓ |
| `analyze` | `flutter analyze` | ✓ | ✓ | ✓ |
| `test` | `flutter test` | | ✓ | ✓ |
| `example_analyze` | `flutter analyze` in `example/` | | ✓ | ✓ |
| `publish_dry_run` | `flutter pub publish --dry-run` | | | ✓ |

- **fast** — static only, a couple of seconds. The working loop.
- **normal** — adds the widget-test suite and the demo app. The default for any change
  under `lib/` or `test/`.
- **full** — adds the pub.dev release gate. Required for `pubspec.yaml`, `CHANGELOG.md`,
  `LICENSE`, `lib/bubbles_sheet.dart` (the public export barrel) and `doc/**` (the
  screenshots `pubspec.yaml` points at, which `publish --dry-run` validates).

Which tier a change *requires* is not a matter of opinion: `tool/harness/lib/classify.mjs`
maps the changed-file set to a tier, and the completion gate takes the highest of (the
task's declared tier, the classifier's tier, the tier the verify run itself recorded).
Declaring `fast` on a change to `pubspec.yaml` does not make it a fast change.

## Known state of this repo (2026-09-21, at bootstrap)

Recorded here because a check that is green for the wrong reason is worse than a red one:

- **`format` currently fails.** 13 of the repo's 14 Dart files are not clean under the
  Dart 3.11 formatter — every file under `lib/src/` and `test/`, plus
  `example/lib/main.dart`. This is pre-existing repository state and was deliberately
  left untouched by the harness bootstrap: `dart format .` would rewrite most of the
  repo, and that is the repo owner's call, not the harness's. Until it is run, **every
  tier comes back `failed`**, `fast` included.
- **`analyze` is clean.** `flutter analyze` reports no issues.
- **`test` is green.** 42 tests across 7 files under `test/`, all passing. Unlike some
  packages this harness has been installed into, there is a real suite here — a `normal`
  run genuinely exercises the widgets.
- **`publish_dry_run` was not exercised at bootstrap.** It is wired and will run; it had
  no reason to run in a `fast` acceptance check.

## Result semantics

`verify.json` (schema 3) carries, at minimum:

| Field | Meaning |
|---|---|
| `result` | `passed` only if every check in the tier actually ran and actually exited zero. `failed` if any check failed. `incomplete` if a required check could not run. |
| `completion_tier_satisfied` | `true` only when `result` is `passed`. |
| `unsatisfied_required` | `[{check, reason}]` — required checks that did not run. Non-empty blocks completion. |
| `required_tier` | What the changed files demand, per the classifier. |
| `tier` | What this run actually executed. |
| `workspace_fingerprint` | Content hash of the changed-file set. Changes after a run make the artifact stale. |
| `verification_policy_fingerprint` | Content hash of the verifier's own files (see `policy_files` in `.claude/docs/routing.yaml`). Editing the verifier invalidates every prior artifact. |
| `checks[]` | Per-check `{name, status, required, exit_code, duration_ms, detail}`. |

A check that could not run — the `flutter` CLI missing, a timeout, no `*_test.dart` under
`test/` — is recorded `skipped` and listed in `unsatisfied_required`, which makes the run
`incomplete`. **`incomplete` is not `passed`.** There is no code path in
`tool/harness/verify` that writes `"status": "passed"` for a command it did not run. Do
not add one.

## Scoping

```
tool/harness/verify normal                       # default: diff against main
tool/harness/verify normal --base <ref>          # diff against an explicit ref
tool/harness/verify fast  --files a.dart b.dart  # an explicit file set
tool/harness/verify fast  --json-out .claude/tasks/<id>/verify.json
```

The scope is recorded in `verify.json`'s `verification_scope` and the gate recomputes the
fingerprint against that same scope — so a `--base`-scoped artifact stays valid instead of
going permanently stale against a differently-scoped default diff.

## Independent review

Optional here, and required only for what consumers compile against: `pubspec.yaml`,
`lib/bubbles_sheet.dart`, `lib/src/bubbles_sheet_theme.dart` and `LICENSE` — see `review:`
in `.claude/docs/routing.yaml`. `tool/harness/review` drives it, pinned to the reviewer
model in that script's `REQUIRED_MODEL` (override with `BUBBLES_SHEET_REVIEW_MODEL`). If
the Codex CLI is unavailable or not authenticated, it writes an `incomplete` review
artifact with the reason; it never writes a passing one it did not obtain.
